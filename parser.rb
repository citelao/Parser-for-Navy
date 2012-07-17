#!/usr/bin/env ruby

require 'csv'
require 'pp'

def parse(file)
	# convert all to string arrays
	arr_of_arrs = CSV.read(file)
	headers = arr_of_arrs.shift.map {|head| head.to_s }
	data = arr_of_arrs.map {|row| row.map {|cell| cell.to_s } }
	
	max_length = arr_of_arrs.max_by(&:length).length	
	puts "Longest row: #{max_length}"
	puts "Headers: #{headers.length}"
	
	headers_to_add = max_length - headers.length
	
	headers_to_add.times do |i|
		headers.push("Ship #{i+1}")
	end
	
	# http://bit.ly/Q4kGVn
	parsed_csv = arr_of_arrs.map {|row| Hash[*headers.zip(row).flatten]}
	
	return parsed_csv
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
	puts "Not Implemented."
	puts "Done!"
	puts
	
	puts "Saving..."
	puts "Not Implemented."
	puts "Done!"
	puts
end