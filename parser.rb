#!/usr/bin/env ruby

require 'csv'
require 'pp'

# Ruby On Rails: http://bit.ly/Nypi1I
class Hash
  def diff(other)
	dup.
	  delete_if { |k, v| other[k] == v }.
	  merge!(other.dup.delete_if { |k, v| has_key?(k) })
  end
end

def parse(file)
	# convert all to string arrays
	arr_of_arrs = CSV.read(file)
	headers = arr_of_arrs.shift.map {|head| head.to_s }
	data = arr_of_arrs.map {|row| row.map {|cell| cell.to_s } }
	
	max_length = arr_of_arrs.max_by(&:length).length
	headers.pop
	
	headers_to_add = max_length - 1 - headers.length
	
	headers_to_add.times do |i|
		headers.push("Ship #{i+1}")
	end
	
	# Shamelessly: http://bit.ly/Q4kGVn
	parsed_csv = arr_of_arrs.map {|row| Hash[*headers.zip(row).flatten]}
	
	return parsed_csv
end

def filter!(data)
	data.each_index do|index|
		row = data[index]
		last_row = data[index-1]
		
		continue if(last_row == nil)
		
		differences = row.diff(last_row)
		
		# Only check for differences in important variables
		differences.delete("Timestamp")
		differences.delete("Width")
		differences.delete("MouseX")
		differences.delete("to_delete")
		
		differences.keep_if {|k, v| last_row[k] == nil || row[k] == nil || k == "Score" }
		
		puts "#{index + 2} #{differences.inspect}" if(differences.length > 0 && $verbose)
		
		row["to_delete"] = (differences.length == 0)
	end
	
	data.delete_if {|row| row["to_delete"] == true }
end

def save(data, filename)
	filename = filename + "1" if (File.exist?(filename))
	
	CSV.open(filename, "wb") do |csv|
		csv << data[0].keys.slice(0, data[0].keys.length-1)
				
		data.each do|row|
			csv << row.values.slice(0, row.values.length-1)
		end
	end
end

ARGV.each do|arg|
	case
	when (arg == "--verbose" || arg == "-v")
		$verbose = true
	when (arg == "--help" || arg == "-h")
		puts "Parser for Navy"
		puts "Parser by Ben Stolovitz <ben@stolovitz.com>"
		puts "Navy by Ben Davison"
		puts
		puts "Usage: `./parser.rb [args] file [file...]`"
		puts "--verbose, -v: verbose messaging"
		puts "--help, -h: this help text"
	else
		puts "Using #{arg} \r\n"
		puts
		
		puts "Parsing..."
		data = parse(arg)
		puts "Done!"
		puts
		
		puts "Filtering..."
		filter!(data)
		puts "Done!"
		puts
						
		puts "Calculating accuracy..."
		puts "Not Implemented."
		puts "Done!"
		puts
		
		puts "Saving..."
		save(data, "#{arg[0...-4]}.treated.log")
		puts "Done!"
		puts

	end
end