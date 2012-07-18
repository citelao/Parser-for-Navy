#!/usr/bin/env ruby

require 'clamp'
require 'csv'
require 'highline'
require 'pp'
require 'progress_bar'

# Ruby On Rails: http://bit.ly/Nypi1I
# Adds a difference comparison for parsing.
class Hash
  def diff(other)
	dup.
	  delete_if { |k, v| other[k] == v }.
	  merge!(other.dup.delete_if { |k, v| has_key?(k) })
  end
end

class Extrapolated_CSV
	# Reads CSV data from a filename into a key-value hash
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
		# Interpolate the headers with the data, then flatten
		# Because Hash accepts [key, value, key, value, ...]
		@csv = arr_of_arrs.map {|row| Hash[*headers.zip(row).flatten]}
		@debug = debug
		return @csv
	end
	
	def [](x)
		@csv[x]
	end
	
	def each(&block)
		@csv.each(&block)
	end
	
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
	
	def extrapolate
		@csv.each_index do|index|
			row = @csv[index]
			last_row = @csv[index-1]
			
			differences = row.diff(last_row)
			
			row["Score"], row["Misses"], row["Hits"] =  "0" \
				if last_row["Timestamp"].to_i > row["Timestamp"].to_i
			
			if differences.has_key?("Score") and \
				last_row["Timestamp"].to_i < row["Timestamp"].to_i
				score_dif = row["Score"].to_i - last_row["Score"].to_i
				case
				when score_dif < 0 # Lost points - miss or ship left screen
					puts "Missed. #{score_dif} #{row['Timestamp']}" \
						if @debug
					row["Misses"] = (last_row["Misses"].to_i + 1).to_s;
				when score_dif  > 0 # Gained points - hit
#					puts "Hit. #{row['Timestamp']}" if verbose?
					row["Hits"] = (last_row["Hits"].to_i + 1).to_s;
				else # da-whuh?
					puts "Um. This shouldn't happen. #{score_dif}"
					puts "Something's broken on Ruby-on-Rail's side. (ln 9)"
				end
				row["Shots"] = (last_row["Shots"].to_i + 1).to_s;
			else 
				row["Shots"], row["Misses"], row["Hits"] =\
					*last_row.values_at("Shots", "Misses", "Hits")
			end
		end
	end
end

class Navy_Parser < Clamp::Command 
	option ["-v", "--verbose"], :flag, "be chatty"
	option ["-d", "--debug"], :flag, "moar output? OK."	
	
	parameter "FILE ...", "input files / folders"
	
	def initialize(unused, also_unused)
		@parsable_files = []
		@bar_flags = [:percentage, :bar, :eta]
		@steps = 4
	end
	
	def file_list=(file)
		file.map do|item|
			Dir.glob("**/*.log") do|file|
				@parsable_files.push(file)
			end if File.directory?(item)
			
			@parsable_files.push(item) unless File.directory?(item)
		end
	end
	
	def execute
		terminal_width = HighLine::SystemExtensions.terminal_size[0]
		
		puts "Parsing #{@parsable_files.length} files."
		
		if verbose?
			print "Parsing..."
			print " " * (terminal_width-10-11)
			print "Step 1 of #{@steps} \r"
			
			parse_bar = ProgressBar.new(@parsable_files.length, *@bar_flags)
		else
			bar = ProgressBar.new(@parsable_files.length * 4, *@bar_flags)
		end
		
		exploded_csvs = Hash.new
		
		@parsable_files.map do|file| 
			parse_bar.increment! if verbose?
			bar.increment! unless verbose?
			
			exploded_csvs[file] = Extrapolated_CSV.new(file, debug?) 
		end
		
		if verbose?
			print "Filtering..."
			print " " * (terminal_width-12-11)
			print "Step 2 of #{@steps} \r"
			
			filter_bar = ProgressBar.new(exploded_csvs.length, *@bar_flags)
		end
		
		exploded_csvs.each do|file, csv|
			filter_bar.increment! if verbose?
			bar.increment! unless verbose?
			
			csv.filter
		end
		
		if verbose?
			print "Extrapolating..."
			print " " * (terminal_width-16-11)
			print "Step 3 of #{@steps} \r"
		
			extrapolate_bar = ProgressBar.new(exploded_csvs.length, *@bar_flags)
		end
		
		exploded_csvs.each do|file, csv|
			extrapolate_bar.increment! if verbose?
			bar.increment! unless verbose?
			
			csv.extrapolate
		end
		
		if verbose?
			print "Saving..."
			print " " * (terminal_width-9-11)
			print "Step 4 of #{@steps} \r"
			
			saving_bar = ProgressBar.new(exploded_csvs.length, *@bar_flags)
		end
		
		exploded_csvs.each do|file, data|
			saving_bar.increment! if verbose?
			bar.increment! unless verbose?
			
			filename = "#{file[0...-4]}.treated.csv"			
			i = 2
			while File.exist?(filename)
				filename = "#{file[0...-4]}.treated.#{i}.csv"
				i += 1
			end
			
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