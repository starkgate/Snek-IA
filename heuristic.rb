require './game.rb'
require './snek.rb'
require 'scanf'

class Heuristic
	def initialize(debug)
		@debug = debug
		@nb_iterations = 50
		@taille_pop = 20
		@percent_best_snek = 0.1

		puts "[SNEK][RUN][initialize] Type y if you want custom values for the snek gaem"
		custom = ' ' # scanf("%c").first
		if custom == 'y'
			puts "[SNEK][RUN][initialize] Type the size of the snek population"
			@taille_pop = scanf("%d").first
			puts "[SNEK][RUN][initialize] Type how many times the algorithm must iterate"
			@nb_iterations = scanf("%d").first
			puts "[SNEK][RUN][initialize] Type the percentage of best sneks that must be used for the next generation"
			@percent_best_snek = scanf("%d").first
		end

		puts "[SNEK][DEBUG][initialize] Creating most smart snek with #{@nb_iterations} iterations of smart algorime" if @debug
		@nb_heuristic = 4
		@heuristic = Array.new(@nb_heuristic)

		@moves=["\e[A","\e[B","\e[C","\e[D"]   # up, down, right, left
		@game = Game.new(true, true, Snek.new(25, 25, []))
		@food = @game.food
		puts "[SNEK][DEBUG][initialize] Initial position of food : #{@food}" if @debug
		@random = Random.new

		genetic_algorithm
	end


	# Fitness pour chacun des moves du snek
	def calcFitness(game_sim)
		fitness = 0
		@heuristic[0] = game_sim.snek.weights[0]*game_sim.distance_from_food
		@heuristic[1] = game_sim.snek.weights[1]*game_sim.score
		@heuristic[2] = game_sim.snek.weights[2]*game_sim.squareness
		@heuristic[3] = game_sim.snek.weights[3]*game_sim.compactness

		@heuristic.each do |h|
			fitness += h
		end
		return fitness
	end

	def rand_population(n)
		pop = []

		n.times do
			weight = []

			@nb_heuristic.times do
				p = @random.rand(5.0).round(5)
				weight.push p
			end
			pop.push Snek.new(((@game.size_x)/2),((@game.size_y)/2), weight)
		end

		puts "[SNEK][DEBUG][rand_population] Population :" if @debug
		puts pop if @debug
		return pop
	end

	# crée un enfant, (un tableau de poids donc) à partir de deux parents
	def child(s1,s2)
		poids = []
		#pour chaque poids dans chaque tableau de pois des deux sneks
		[s1.weights,s2.weights].each_with_index  do |w1,w2, i|
			poids[i] = [w1,w2].sample

			#Mutation à rajouter
		end
		return poids
	end

	#crée tous les enfants et remplissasse la population
	def children(pop)
		children = []
		#On rempli avec des nouveaux sneks random
		children = rand_population(@taille_pop-pop.length)
		#On rempli la population avec les enfants des meilleurs, chaque meilleur va se reproduire avec deux autres meilleurs, un genre de polygamisme quoi
		(@taille_pop-1).upto(pop.length) do |i|
			if i < pop.length
				children[i] = Snek.new(((@game.size_x)/2),((@game.size_y)/2),child(pop[i],pop[i+1]))
			else
				children[i] = Snek.new(((@game.size_x)/2),((@game.size_y)/2),child(pop[i],pop[0]))
			end
		end
		return children
	end

	def genetic_algorithm
		population = rand_population(@taille_pop)
		@nb_iterations.times do |i|
			# Le meilleur snek

			# Renvoie les 10% des meilleurs individus
			sneks_to_breed = best(population)
			@best_snek = max(sneks_to_breed) if (i+1) == @nb_iterations
			# On génére une nouvelle population à partir de ceux-là
			children = children(sneks_to_breed)

			puts "[SNEK][DEBUG][genetic_algorithm] Iteration #{i}" if @debug
			puts "[SNEK][DEBUG][genetic_algorithm] Best sneks :" if @debug
			puts sneks_to_breed if @debug
			puts "[SNEK][DEBUG][genetic_algorithm] Children of best sneks" if @debug
			puts children if @debug

			# On mute les meilleurs sneks et on reset leur position
			mutate(sneks_to_breed)

			puts "[SNEK][DEBUG][genetic_algorithm] Mutated sneks :" if @debug
			puts sneks_to_breed if @debug

			# On merge les enfants et les parents
			population = children + sneks_to_breed
			@percent_best_snek += @percent_best_snek if (i % (@nb_iterations/10) == 0) && (@percent_best_snek < 0.8)
			puts "#{i} : #{@percent_best_snek}"
		end
		puts "Sickestest snek after #{@nb_iterations} iterations : #{@best_snek}, with a score of #{@score_pop[@best_snek.id]}"
	end

	def one_move
		best_fit=["",-1]

		#faire jouer le snek
		@moves.each do |m|
			game_sim = Game.new(false,true,@game_snek.snek.clone)
			game_sim.score = @game_snek.score.clone
			game_sim.food = @game_snek.food.clone
			game_sim.snek.pos = @game_snek.snek.pos.clone
			game_sim.moves_since_food = @game_snek.moves_since_food.clone
			game_sim.next_frame(m)
			game_sim.food = @game_snek.food.clone # don't touch this, used so that we don't fuck up the distance_from_food
			
			@fitness = calcFitness(game_sim)

			best_fit = [m, @fitness] if @fitness >= best_fit[1]
		end
		

		if @debug
			move = ""
			case best_fit[0]
			when "\e[A" # up
				move = "up"
			when "\e[B" # down
				move = "down"
			when "\e[C" # right
				move = "right"
			when "\e[D" # left
				move = "left"
			end
			puts "[SNEK][DEBUG][one_move] Fit = #{@fitness}, snek moving #{move}"
		end

		p @game_snek.snek.pos
		return best_fit[0]
	end

	# On va faire jouer tous les sneks et voir qui sont les meilleurs avec sickestest
	def best(pop)
		@score_pop = Hash.new
		pop.each do |snek|
			@game_snek = Game.new(false, true, snek)
			puts "[SNEK][DEBUG][best] On joue avec : #{snek}" if @debug
			# On joue jusqu'à la mort
			@game_snek.next_frame one_move until @game_snek.game_over?

			puts "[SNEK][DEBUG][best] Score du snek #{snek.id} : #{@game_snek.score}" if @debug
			# le snek est mort, l'ajouter à la hash map
			@score_pop[snek.id] = @game_snek.score
		end
		sickestest_sneks = sickestest(pop, 0.1)
		return sickestest_sneks
	end

	# Rend les meilleurs sneks parmis une population de snek et score, avec pourvent le pourcentage des meilleurs
	def sickestest(pop, pourcent)
		#nb de meilleurs snek à garder
		@nb_breeding_pool = (pourcent*pop.length.to_f).round

		sneks_to_breed = []
		#on prend le meilleur et on l'enlève de la pop, pour recommencer jusqu'à temps qu'on ai les 10% de meilleurs sneks dans 'sneks_to_breed'
		@nb_breeding_pool.times do
			best = max(pop)
			puts "[SNEK][DEBUG][max] Best snek de la population : #{best}" if @debug
			pop.delete best
			sneks_to_breed.push best
		end
		return sneks_to_breed
	end

	def max(pop)
		puts "[SNEK][DEBUG][max] Max de la population : " if @debug
		puts pop if @debug
		max, max_snek = -1, nil
		pop.each do |snek|
			max, max_snek = @score_pop[snek.id], snek if @score_pop[snek.id] >= max
		end
		return max_snek
	end

	def mutate(sneks)
		puts "[SNEK][DEBUG][mutate] On mute la population : " if @debug
		puts sneks if @debug
		sneks.each do |snek|
			snek.pos = [[25,25]]

			@random.rand(snek.weights.length).times do # do random number of modifications on random indexes
				snek.weights[@random.rand(snek.weights.length)] += @random.rand(5.0)*@percent_best_snek*@random.rand(-1..1)
			end
		end
	end
end

Heuristic.new(false)