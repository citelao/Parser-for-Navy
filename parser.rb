#!/usr/bin/env ruby

require 'csv'
require 'pp'
require 'clamp'
require 'progress_bar'

# Ruby On Rails: http://bit.ly/Nypi1I
class Hash
  def diff(other)
	dup.
	  delete_if { |k, v| other[k] == v }.
	  merge!(other.dup.delete_if { |k, v| has_key?(k) })
  end
end

class NavyParser < Clamp::Command 
	option ["-v", "--verbose"], :flag, "be chatty"
	
	parameter "FILE ...", "input files / folders"
	
	def initialize(unused, also_unused)
		@parsable_files = []
		@bar_flags = [:percentage, :bar, :eta]
	end
	
	def file_list=(file)
		file.map do|item|
			Dir.glob("**/*.log") do|file|
				@parsable_files.push(file)
			end if File.directory?(item)
			
			@parsable_files.push(item) unless File.directory?(item)
		end
	end
	
	def csv_parse(file)		
		arr_of_arrs = CSV.read(file)
		
		headers = arr_of_arrs.shift.map {|head| head.to_s }
		data = arr_of_arrs.map {|row| row.map {|cell| cell.to_s } }
		
		max_length = arr_of_arrs.max_by(&:length).length
		headers.delete("Ships")
		
		headers_to_add = max_length - headers.length 	
		headers_to_add.times do |i|
			headers.push("Ship #{i+1}")
		end
		
		# Shamelessly: http://bit.ly/Q4kGVn
		return arr_of_arrs.map \
		 {|row| Hash[*headers.zip(row).flatten]}
	end
	
	def csv_filter(exploded_csv)
		exploded_csv.each_index do|index|
			row = exploded_csv[index]
			last_row = exploded_csv[index-1]
			
			continue if(last_row == nil)
			
			differences = row.diff(last_row)
			
			# Only check for differences in important variables
			differences.delete("Timestamp")
			differences.delete("Width")
			differences.delete("MouseX")
			differences.delete("to_delete")
			
			differences.keep_if do|k, v| 
				last_row[k] == nil || row[k] == nil || k == "Score" 
			end
			
			puts "#{index + 2} #{differences.inspect}" \
			 if(differences.length > 0 && verbose?)
			
			row["to_delete"] = (differences.length == 0)
		end
		
		exploded_csv.delete_if {|row| row["to_delete"] == true }
		exploded_csv.each{|row| row.delete("to_delete")}
		
		return exploded_csv
	end
	
	def execute
		puts "Parsing..."
		parse_bar = ProgressBar.new(@parsable_files.length, *@bar_flags)
		
		exploded_csv = Hash.new
		@parsable_files.map do|file| 
			parse_bar.increment!
			exploded_csv[file] = csv_parse(file) 
		end
		
		puts "Filtering..."
		filter_bar = ProgressBar.new(exploded_csv.length, *@bar_flags)
		
		filtered_csv = Hash.new
		exploded_csv.each do|key, data|
			filter_bar.increment!
			filtered_csv[key] = csv_filter(data)
		end
		
		puts "Saving..."
		saving_bar = ProgressBar.new(@parsable_files.length, *@bar_flags)
		
		filtered_csv.each do|file, data|
			saving_bar.increment!
			
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

NavyParser.run