"""
Genetic algorithm-based drink planner for Bartendro.
Optimizes booze selection to maximize the number of drinks that can be made.
"""

import random
import threading
from sqlalchemy import text
from bartendro import db
from bartendro.model.booze import Booze
from bartendro.model.drink import Drink


class DrinkPlanner:
    def __init__(self, num_dispensers, locked_boozes, blocked_boozes=None):
        """
        Initialize the planner.
        
        Args:
            num_dispensers: Total number of dispensers available
            locked_boozes: List of booze IDs that are locked (user-selected)
            blocked_boozes: List of booze IDs that should never be suggested
        """
        self.num_dispensers = num_dispensers
        self.locked_boozes = [b for b in locked_boozes if b > 0]
        self.blocked_boozes = blocked_boozes or []
        self.num_to_fill = num_dispensers - len(self.locked_boozes)
        
        # Get all available boozes (excluding locked and blocked ones)
        self.all_boozes = self._get_all_boozes()
        self.available_boozes = [b for b in self.all_boozes if b not in self.locked_boozes and b not in self.blocked_boozes]
        
        # Get drink requirements for fitness calculation
        self.drink_requirements = self._get_drink_requirements()
        
        # Planning state
        self.best_solution = None
        self.best_fitness = 0
        self.generation = 0
        self.is_running = False
        self.thread = None
        
    def _get_all_boozes(self):
        """Get list of all booze IDs."""
        boozes = db.session.query(Booze.id).all()
        return [b[0] for b in boozes]
    
    def _get_drink_requirements(self):
        """Get the booze requirements for each drink."""
        drinks = db.session.query(Drink.id, Booze.id)\
                    .from_statement(text("""SELECT d.id AS drink_id, db.booze_id AS booze_id
                                              FROM drink d, drink_booze db
                                             WHERE db.drink_id = d.id
                                               AND d.available = 1
                                          ORDER BY d.id, db.booze_id""")).all()
        
        drink_reqs = {}
        for drink_id, booze_id in drinks:
            if drink_id not in drink_reqs:
                drink_reqs[drink_id] = set()
            drink_reqs[drink_id].add(booze_id)
        
        return drink_reqs
    
    def _calculate_fitness(self, chromosome):
        """
        Calculate fitness as the number of drinks that can be made.
        
        Args:
            chromosome: List of booze IDs (the suggested boozes to fill remaining slots)
        
        Returns:
            Number of drinks that can be made with the full booze selection
        """
        # Combine locked boozes with chromosome
        all_selected = set(self.locked_boozes + list(chromosome))
        
        # Count how many drinks can be made
        can_make = 0
        for drink_id, required_boozes in self.drink_requirements.items():
            if required_boozes.issubset(all_selected):
                can_make += 1
        
        return can_make
    
    def _create_individual(self):
        """Create a random individual (chromosome) for the population."""
        if self.num_to_fill <= 0:
            return []
        return random.sample(self.available_boozes, min(self.num_to_fill, len(self.available_boozes)))
    
    def _crossover(self, parent1, parent2):
        """Perform crossover between two parents."""
        if len(parent1) <= 1:
            return parent1[:], parent2[:]
        
        # Use order crossover to maintain unique boozes
        child1 = []
        child2 = []
        
        # Take half from each parent, fill rest from other parent
        half = len(parent1) // 2
        child1 = parent1[:half]
        for booze in parent2:
            if booze not in child1 and len(child1) < self.num_to_fill:
                child1.append(booze)
        
        child2 = parent2[:half]
        for booze in parent1:
            if booze not in child2 and len(child2) < self.num_to_fill:
                child2.append(booze)
        
        # Fill remaining slots with random boozes if needed
        remaining1 = [b for b in self.available_boozes if b not in child1]
        remaining2 = [b for b in self.available_boozes if b not in child2]
        
        while len(child1) < self.num_to_fill and remaining1:
            booze = random.choice(remaining1)
            child1.append(booze)
            remaining1.remove(booze)
        
        while len(child2) < self.num_to_fill and remaining2:
            booze = random.choice(remaining2)
            child2.append(booze)
            remaining2.remove(booze)
        
        return child1, child2
    
    def _mutate(self, individual, mutation_rate=0.1):
        """Mutate an individual by swapping boozes."""
        if random.random() < mutation_rate and len(individual) > 0:
            # Replace one booze with a random one not in the selection
            idx = random.randint(0, len(individual) - 1)
            current = set(individual) | set(self.locked_boozes)
            available = [b for b in self.available_boozes if b not in current]
            if available:
                individual[idx] = random.choice(available)
        return individual
    
    def _run_generation(self, population, population_size=50):
        """Run one generation of the genetic algorithm."""
        # Calculate fitness for all individuals
        fitness_scores = [(ind, self._calculate_fitness(ind)) for ind in population]
        fitness_scores.sort(key=lambda x: x[1], reverse=True)
        
        # Update best solution if we found a better one
        if fitness_scores[0][1] > self.best_fitness:
            self.best_fitness = fitness_scores[0][1]
            self.best_solution = fitness_scores[0][0][:]
        
        # Selection: keep top 50%
        survivors = [ind for ind, _ in fitness_scores[:population_size // 2]]
        
        # Create new population through crossover and mutation
        new_population = survivors[:]
        while len(new_population) < population_size:
            parent1, parent2 = random.sample(survivors, 2)
            child1, child2 = self._crossover(parent1, parent2)
            new_population.append(self._mutate(child1))
            if len(new_population) < population_size:
                new_population.append(self._mutate(child2))
        
        self.generation += 1
        return new_population
    
    def _planning_loop(self, max_generations=100, population_size=50):
        """Main planning loop that runs in a background thread."""
        # Initialize population
        population = [self._create_individual() for _ in range(population_size)]
        
        # Run initial fitness to set best solution
        if population:
            fitness_scores = [(ind, self._calculate_fitness(ind)) for ind in population]
            fitness_scores.sort(key=lambda x: x[1], reverse=True)
            self.best_fitness = fitness_scores[0][1]
            self.best_solution = fitness_scores[0][0][:]
        
        while self.is_running and self.generation < max_generations:
            population = self._run_generation(population, population_size)
        
        self.is_running = False
    
    def start(self):
        """Start the planning process in a background thread."""
        if self.is_running:
            return
        
        self.is_running = True
        self.generation = 0
        self.best_solution = None
        self.best_fitness = 0
        
        self.thread = threading.Thread(target=self._planning_loop)
        self.thread.daemon = True
        self.thread.start()
    
    def stop(self):
        """Stop the planning process."""
        self.is_running = False
        if self.thread:
            self.thread.join(timeout=1.0)
    
    def get_status(self):
        """Get the current planning status."""
        return {
            'is_running': self.is_running,
            'generation': self.generation,
            'best_fitness': self.best_fitness,
            'best_solution': self.best_solution,
            'locked_boozes': self.locked_boozes
        }


# Global planner instance
_current_planner = None
_planner_lock = threading.Lock()


def start_planning(num_dispensers, locked_boozes, blocked_boozes=None):
    """Start a new planning session."""
    global _current_planner
    
    with _planner_lock:
        if _current_planner:
            _current_planner.stop()
        
        _current_planner = DrinkPlanner(num_dispensers, locked_boozes, blocked_boozes)
        _current_planner.start()
    
    return {'status': 'started'}


def stop_planning():
    """Stop the current planning session."""
    global _current_planner
    
    with _planner_lock:
        if _current_planner:
            _current_planner.stop()
            _current_planner = None
    
    return {'status': 'stopped'}


def get_planning_status():
    """Get the status of the current planning session."""
    global _current_planner
    
    with _planner_lock:
        if _current_planner:
            return _current_planner.get_status()
        else:
            return {
                'is_running': False,
                'generation': 0,
                'best_fitness': 0,
                'best_solution': None,
                'locked_boozes': []
            }
