#!/usr/bin/env ruby

require 'csv'
require 'pp'

# Ruby On Rails: http://bit.ly/Nypi1I
class Hash
  # Returns a hash that represents the difference between two hashes.
  #
  #   {1 => 2}.diff(1 => 2)         # => {}
  #   {1 => 2}.diff(1 => 3)         # => {1 => 2}
  #   {}.diff(1 => 2)               # => {1 => 2}
  #   {1 => 2, 3 => 4}.diff(1 => 2) # => {3 => 4}
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
	
	headers_to_add = max_length - headers.length
	
	headers_to_add.times do |i|
		headers.push("Ship #{i+1}")
	end
	
	# Shamelessly: http://bit.ly/Q4kGVn
	parsed_csv = arr_of_arrs.map {|row| Hash[*headers.zip(row).flatten]}
	
	return parsed_csv
end

def filter!(file)
	file.each_index do|index|
		row = file[index]
		last_row = file[index-1]
		
		continue if(last_row == nil)
		
		differences = row.diff(last_row)
		
		# Only check for differences in important variables
		differences.delete("Timestamp").delete("Width").delete("MouseX").delete("Ships")
		
		differences.keep_if {|k, v| last_row[k] == nil }
		
		puts index if(differences.length > 0)
	end
	
	file.replace(filtered_file)
end


if(ARGV[0] == nil)
	ARGV[0] = '/Users/citelao/Desktop/navy logs - start/navy_activity-1340907930347.log'
end

ARGV.each do|file|
	puts "Using #{file} \r\n"
	puts
	
	puts "Parsing..."
	data = parse(file)
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
	puts "Not Implemented."
	puts "Done!"
	puts
end