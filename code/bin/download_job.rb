require 'net/http'
require 'open-uri'
require 'json'
require 'date'
require 'time'
require 'fileutils'
require 'travis'
require 'uri'
require 'find'
require 'open_uri_redirections'

#@date_threshold = Date.parse("2019-02-02")
#zh
module DownloadJobs
  def self.download_job(job_id,name)
    puts 'download jobs begin'
    job_log_url="http://s3.amazonaws.com/archive.travis-ci.org/jobs/#{job_id}/log.txt"
    count = 0
    f = ''
    begin
      if job_log_url.include?('amazonaws')
        open(job_log_url,'Content-Type'=>'text/plain','Accept'=> 'text/plain',:allow_redirections => :all) { |o| f = o.read }
      else
        open(job_log_url,'Travis-API-Version'=>'3','Authorization'=>'token xukZXnxq2DWJOJU4ETvQ5A','Accept'=> 'text/plain',:allow_redirections => :all) { |o| f = o.read }
        puts"reopen #{job_log_url}"
        # open(job_log_url,'Content-Type'=>'text/plain','Accept'=> 'text/plain',:allow_redirections => :all) { |o| f = o.read }
      end
    rescue => e
      puts "Retrying, #{count} times fail to download job log #{job_log_url}: #{e.message}"
      job_log_url = "http://api.travis-ci.org/jobs/#{job_id}/log" # if e.message.include?('403')
      # job_log_url ="http://api.travis-ci.com/job/#{job_id}/log"
      f = ''
      sleep 10
      count += 1
      retry if count < 2
    end
    f
    File.open(name, 'w') { |info| info.puts f }
    puts "download logssssss"
    f = ''
  end

# def self.download_job(job, name, wait_in_s = 1)
#   if (wait_in_s > 64)
#     STDERR.puts "Error: Giveup: We can't wait forever for #{job}"
#     return 0
#   elsif (wait_in_s > 1)
#     sleep wait_in_s
#   end

#   begin
#     begin
#       log_url = "http://s3.amazonaws.com/archive.travis-ci.org/jobs/#{job}/log.txt"
#       STDERR.puts "Attempt 1 #{log_url}"
#       log = Net::HTTP.get_response(URI.parse(log_url)).body
#     rescue
#       # Workaround if log.body results in error.
#       log_url = "http://s3.amazonaws.com/archive.travis-ci.org/jobs/#{job}/log.txt"
#       STDERR.puts "Attempt 2 #{log_url}"
#       log = Net::HTTP.get_response(URI.parse(log_url)).body
#     end

#     File.open(name, 'w') { |f| f.puts log }
#     puts "download log"
#     log = '' # necessary to enable GC of previously stored value, otherwise: memory leak
#   rescue
#     error_message = "Retrying, but Could not get log #{name}"
#     puts error_message
#     File.open(@error_file, 'a') { |f| f.puts error_message }
#     download_job(job, wait_in_s*2)
#   end
# end

def self.job_logs(path,job_id)
  
    #name = File.expand_path(File.join('..', '..', '..', 'bodyLog2', 'build_logs', 'google@guava', '1000@1.log'), File.dirname(__FILE__))
    unless (File.exists?(path) and File.size(path) > 5)
      puts "downliad-"
      
      download_job(job_id,path)
    end
  
end
end 

#   job_log_url="http://s3.amazonaws.com/archive.travis-ci.org/jobs/#{job_id}"
#   count = 0
#   f = ''
#   begin
#     if job_log_url.include?('amazonaws')
#       open(job_log_url) { |o| f = o.read }
#     else
# #         open(job_log_url,'Travis-API-Version'=>'3','Authorization'=>'token 
# # xukZXnxq2DWJOJU4ETvQ5A','Accept'=> 'text/plain',:allow_redirections => :all) { |o| f = o.read }
#     open(job_log_url,'Content-Type'=>'text/plain','Accept'=> 'text/plain',:allow_redirections => :all) { |o| f = o.read }
#     end
#   rescue => e
#     puts "Retrying, #{count} times fail to download job log #{job_log_url}: #{e.message}"
#     job_log_url = "http://api.travis-ci.org/jobs/#{job_id}" # if e.message.include?('403')
#     f = ''
#     sleep 10
#     count += 1
#     retry if count < 5
#   end
#   f
#   return f
#   #File.open(name, 'w') { |info| info.puts f }
#   puts "download log"
#   f = ''




  # path = File.expand_path(File.join('..', '..', '..', 'bodyLog2', 'build_logs', 'UniversalMediaServer@UniversalMediaServer', 'test@1.log'), File.dirname(__FILE__))
  # dir_path=File.expand_path(File.join('..', '..', '..', 'bodyLog2', 'build_logs', 'l0rdn1kk0n@wicket-bootstrap'), File.dirname(__FILE__))
  # if !File.directory?(dir_path)
  #     FileUtils::mkdir_p(dir_path)
  # end


