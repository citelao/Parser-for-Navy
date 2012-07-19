#!/usr/bin/env ruby

require 'clamp'
require 'csv'
require 'highline'
require 'pp'
require 'progress_bar'

##
# Hash implementation of #diff(), taken from 
# Ruby on Rails <http://bit.ly/Nypi1I>
class Hash
	
	##
	# The infamous Hash#diff() function. Used for comparing lines.
	def diff(other)
	dup.
		delete_if { |k, v| other[k] == v }.
		merge!(other.dup.delete_if { |k, v| has_key?(k) })
	end
end

##
# Class for handling all CSVs used in this project. Passed a filename and a
# debug mode (to determine level of output), this class parses, filters––
# everything that this whole parser app does.
class Extrapolated_CSV
	
	##
	# Reads CSV data from a filename into a readable key-value hash
	def initialize(file, debug = false)
		arr_of_arrs = CSV.read(file)
		
		headers = arr_of_arrs.shift.map {|head| head.to_s }
		data = arr_of_arrs.map {|row| row.map {|cell| cell.to_s } }
		
		max_length = arr_of_arrs.max_by(&:length).length
		headers.delete("Ships")	# Remove the ambiguous header "Ships"
								# It will become "Ship 1"
		
		headers_to_add = max_length - headers.length 	
		headers_to_add.times {|i| headers.push("Ship #{i+1}") } \
			unless headers_to_add < 1
		
		# Add extrapolated headers
		headers.push("Shots")
		headers.push("Hits")
		headers.push("Misses")
		
		# Shamelessly: http://bit.ly/Q4kGVn
		# Interpolate the headers with the data, then flatten because Hash
		# accepts [key, value, key, value, ...]
		@csv = arr_of_arrs.map {|row| Hash[*headers.zip(row).flatten]}
		@debug = debug
		return @csv
	end
	
	##
	# Returns location [x] in CSV.
	def [](x)
		@csv[x]
	end
	
	##
	# Iterates through the CSV.
	def each(&block)
		@csv.each(&block)
	end
	
	##
	# Strips all redundant lines
	def filter
		@csv.each_index do|index|
			row = @csv[index]
			last_row = @csv[index-1]
			
			# Arrays *love* wrapping around at the beginning
			# Array[-1] returns the last element-- that's not good
			next if(last_row["Timestamp"].to_i > row["Timestamp"].to_i)
			
			differences = row.diff(last_row)
			
			# Only check for differences in important variables
			differences.delete("Timestamp")
			differences.delete("Width")
			differences.delete("MouseX")
			differences.delete("to_delete")
			
			differences.keep_if do|k, v| 
				last_row[k] == nil || row[k] == nil || k == "Score" 
			end
			
			# List differences by line in --debug mode
			puts "ln #{index + 2}: #{differences.inspect}" \
			 if(differences.length > 0 && @debug)
			
			# Add deletion key to each element. They are deleted later.
			row["to_delete"] = (differences.length == 0)
		end
		
		@csv.delete_if {|row| row["to_delete"] == true }
		@csv.each{|row| row.delete("to_delete")}
	end
	
	##
	# Calculates shots, missage, and hittage.
	#
	# This method assumes that no more than one click may happen per frame.
	# Since one shot may destroy multiple ships, "Shots" accurately reflects
	# clicks, while "Hits" accurately reflects destroyed ships.
	#
	# This is unacceptable for edge cases (see `small.log`) like times where
	# multiple frames are missing leading to mega score changes. However
	# there is no real way to derive accurate data from that, considering that
	# multiple combinations of hits, misses, and shots may be reflected by a
	# single score:
	#
	# 12pts => 10 hits, 8 misses => 18 shots OR
	# 12pts => 6 hits, 0 misses => 6 shots.
	#
	# The best I can do with flawed data like that is take the smallest shot 
	# change possible: assume all hits, rounding away any decimals. Flawed?
	# Yes. But those are flaws with the data the program CANNOT work around.
	#
	# Suggested workaround:	Mark any large jumps in timestamp / score as INVALID
	# 						when graphing and looking at data in Excel, etc.
	#
	# Any flaws => your fault :)
	def extrapolate
		@csv.each_index do|index|
			row = @csv[index]
			last_row = @csv[index-1]
			
			differences = row.diff(last_row)
			
			# Since the array wraps, set everything to 0 if it	finds the 
			# previous timestamp (ie final index) to be greater than the
			# current one.
			is_first = last_row["Timestamp"].to_i > row["Timestamp"].to_i
			row["Score"], row["Misses"], row["Hits"] =	"0" if is_first
			
			if !is_first
				# Set all to previous then override
				row["Shots"] = last_row["Shots"]
				row["Misses"] = last_row["Misses"]
				row["Hits"] = last_row["Hits"]
						
				if differences.has_key?("Score")
					score_dif = row["Score"].to_i - last_row["Score"].to_i
					
					row["Shots"] = (last_row["Shots"].to_i + 1).to_s
					
					case
					when score_dif < 0
						# Lost points => Miss or ship left screen
						row["Misses"] = (last_row["Misses"].to_i + \
							score_dif.abs).to_s
						
						puts "Missed #{row['Misses']}/#{row['Shots']} @ \
							#{row['Timestamp']}" if @debug
							
					when score_dif > 0
						# Gained points => Hit
						# 2 Points = 1 Hit.
						row["Hits"] = (last_row["Hits"].to_i + \
							score_dif.abs / 2).to_s
						
						puts "Hit #{row['Hits']}/#{row['Shots']} @ \
						#{row['Timestamp']}" if @debug
					end
				end
			end
		end
	end
end # Extrapolated_CSV

##
# CLI for parser.
class Navy_Parser < Clamp::Command 
	self.description = %{
		Parse Navy's .log files.
		
		Parser by Ben Stolovitz. CC BY-SA 3.0.
		Navy by Ben Davison.
	}
	
	option ["-v", "--verbose"], :flag, "be chatty"
	option ["-d", "--debug"], :flag, "moar output? OK."	
	
	option ["--version"], :flag, "show version" do
		puts "Navy Parser v0.9rc1"
		puts "Powered by Clamp-#{Clamp::VERSION}"
		exit(0)
	  end

	
	parameter "FILE ...", "input files / folders"
	
	##
	# Initialize basically sets up variables I could not use otherwise.
	def initialize(unused, but_still_waiting_and_watching_silently)
		# Since this extends Clamp::Command, I have to use the required 
		# variables. I don't need them so I don't care what they're named.
		@parsable_files = []
		@bar_flags = [:percentage, :bar, :eta]
		@steps = 4
	end
	
	##
	# Extension of Clamp's variable parsing, finds all usable (.log) files 
	# recursively through folders and files passed.
	def file_list=(file)
		file.map do|item|
			Dir.glob("**/*.log") do|file|
				@parsable_files.push(file)
			end if File.directory?(item)
			
			@parsable_files.push(item) unless File.directory?(item)
		end
	end
	
	##
	# Passes parsable files to an array of Extrapolated_CSVs. Then does
	# everything and writes to screen depending on the verbosity.
	def execute
		
		# This will not live update, but neither do the progress bars, really.
		terminal_width = HighLine::SystemExtensions.terminal_size[0]
		
		puts "Parsing #{@parsable_files.length} files."
		
		if verbose?
			print "Parsing..."
			# In order to float right.
			print " " * (terminal_width-10-11)
			print "Step 1 of #{@steps} \r"
			
			bar = ProgressBar.new(@parsable_files.length, *@bar_flags)
		else
			bar = ProgressBar.new(@parsable_files.length * 4, *@bar_flags)
		end
		
		extrapolated_csvs = Hash.new
		
		# Create a list of new Extrapolated_CSV for each parsable CSV.
		@parsable_files.map do|file| 
			bar.increment!
			extrapolated_csvs[file] = Extrapolated_CSV.new(file, debug?) 
		end
		
		if verbose?
			print "Filtering..."
			print " " * (terminal_width-12-11)
			print "Step 2 of #{@steps} \r"
			
			bar = ProgressBar.new(extrapolated_csvs.length, *@bar_flags)
		end
		
		extrapolated_csvs.each do|file, csv|
			bar.increment!
			csv.filter
		end
		
		if verbose?
			print "Extrapolating..."
			print " " * (terminal_width-16-11)
			print "Step 3 of #{@steps} \r"
		
			bar = ProgressBar.new(extrapolated_csvs.length, *@bar_flags)
		end
		
		extrapolated_csvs.each do|file, csv|
			bar.increment!	
			csv.extrapolate
		end
		
		if verbose?
			print "Saving..."
			print " " * (terminal_width-9-11)
			print "Step 4 of #{@steps} \r"
			
			bar = ProgressBar.new(extrapolated_csvs.length, *@bar_flags)
		end
		
		extrapolated_csvs.each do|file, data|
			bar.increment!
			
			filename = "#{file[0...-4]}.treated.csv"
			
			# In case of file conflicts, iterate until a better name is found.
			i = 2
			while File.exist?(filename)
				filename = "#{file[0...-4]}.treated.#{i}.csv"
				i += 1
			end
			
			# Write to file.
			CSV.open(filename, "wb") do |csv|
				csv << data[0].keys
						
				data.each do|row|
					csv << row.values
				end
			end
		end
	end
end

Navy_Parser.run