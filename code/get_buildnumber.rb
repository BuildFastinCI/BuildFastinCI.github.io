#!/usr/bin/env ruby
'''
会发生build缺失的情况.threerings tripleplay为例，代码抓取的最早的build信息是2013-05-26，但是在GitHub上还有更早的commit
'''
# Occassionally, Travis fails to include. This is a never-give-up safeguard against such behavior

def self.include_travis
  begin
    require 'travis'
  rescue
    error_message = "Error: Problem including Travis. Retrying ..."
    puts error_message
    sleep 2
    include_travis
  end
end

include_travis
require 'net/http'
require 'open-uri'
require 'json'
require 'date'
require 'time'
require 'fileutils'
require 'thread'
require File.expand_path('../lib/build_number.rb',__FILE__)
require File.expand_path('../fix_sql.rb',__FILE__)
load 'lib/csv_helper.rb'
@thread_num=30
@date_threshold = Date.parse("2019-02-02")
#zh
def download_job(job, name, wait_in_s = 1)
  if (wait_in_s > 64)
    STDERR.puts "Error: Giveup: We can't wait forever for #{job}"
    return 0
  elsif (wait_in_s > 1)
    sleep wait_in_s
  end

  begin
    begin
      log_url = "http://s3.amazonaws.com/archive.travis-ci.org/jobs/#{job}/log.txt"
      STDERR.puts "Attempt 1 #{log_url}"
      log = Net::HTTP.get_response(URI.parse(log_url)).body
    rescue
      # Workaround if log.body results in error.
      log_url = "http://s3.amazonaws.com/archive.travis-ci.org/jobs/#{job}/log.txt"
      STDERR.puts "Attempt 2 #{log_url}"
      log = Net::HTTP.get_response(URI.parse(log_url)).body
    end

    File.open(name, 'w') { |f| f.puts log }
    log = '' # necessary to enable GC of previously stored value, otherwise: memory leak
  rescue
    error_message = "Retrying, but Could not get log #{name}"
    puts error_message
    File.open(@error_file, 'a') { |f| f.puts error_message }
    download_job(job, wait_in_s*2)
  end
end

def job_logs(build, sha)
  jobs = build['job_ids']
  jobs.each do |job|
    name = File.join(@parent_dir, "#{build['number']}_#{build['id']}_#{sha}_#{job}.log")
    next if File.exists?(name) and File.size(name) > 1

    download_job(job, name)
  end
end

def get_build(builds, build, wait_in_s = 1)
  if (wait_in_s > 64)
    STDERR.puts "Error: Giveup: We can't wait forever for #{build}"
    return {}
  elsif (wait_in_s > 1)
    sleep wait_in_s
  end

  begin
    begin
      started_at = Time.parse(build['started_at']).utc.to_s
      return {} if Date.parse(started_at) >= @date_threshold
    rescue
      begin
        ended_at = Time.parse(build['finished_at']).utc.to_s
      rescue
        error_message = "Skipping empty date #{build['id']}"
        puts error_message
        return {}
      end
      #return {} if Date.parse(ended_at) <= @date_threshold
    end

    commit = builds['commits'].find { |x| x['id'] == build['commit_id'] }
    #puts "build"
    # puts build

    build_data = {
        :build_id => build['id'],
        :build_number=> build['number'],
        :ended_at => build['finished_at'],      # [doc] The unique Travis IDs of the jobs, in a string separated by `#`.
        :started_at => build['started_at']
    }

    return build_data
  rescue Exception => e
    error_message = "Retrying, but Error getting Travis build #{build['id']}: #{e.message}"
    puts error_message
    File.open(@error_file, 'a') { |f| f.puts error_message }
    return get_build(build, wait_in_s*2)
  end

end

def paginate_build(last_build, repo_id, wait_in_s = 1)
  if (wait_in_s > 128)
    STDERR.puts "Error: Giveup: We can't wait forever for #{repo}"
    return 0
  elsif (wait_in_s > 1)
    sleep wait_in_s
  end

  all_builds = []

  begin
    url = "https://api.travis-ci.org/builds?after_number=#{last_build}&repository_id=#{repo_id}"
    STDERR.puts url

    resp = open(url,
                'Content-Type' => 'application/json',
                'Accept' => 'application/vnd.travis-ci.2+json')
    builds = JSON.parse(resp.read)
    #puts "builds_key:#{builds.keys}"
    #puts JSON.pretty_generate(builds)
    builds['builds'].each do |build|
      
      
      all_builds << get_build(builds, build)
    end

    return all_builds
  rescue  Exception => e
    error_message = "Retrying, but Error paginating Travis build #{last_build}: #{e.message}"
    puts error_message
    File.open(@error_file, 'a') { |f| f.puts error_message }
    return paginate_build(last_build, repo_id, wait_in_s*2)
  end

end

def get_travis(repo, build_logs = true, wait_in_s = 1)
  if (wait_in_s > 128)
    STDERR.puts "Error: Giveup: We can't wait forever for #{repo}"
    return 0
  elsif (wait_in_s > 1)
    sleep wait_in_s
  end

  @parent_dir = File.join('build_logs/', repo.gsub(/\//, '@'))
  @error_file = File.join(@parent_dir, 'errors')
  @build_logs = build_logs
  FileUtils::mkdir_p(@parent_dir)
  json_file = File.join(@parent_dir, 'build_number.json')

  all_builds = []

  begin
    repository = Travis::Repository.find(repo)

    highest_build = repository.last_build_number.to_i
    
    puts "Harvesting Travis build logs for #{repo} (#{highest_build} builds)"
    while true do
      highest_build = highest_build + 1
      if highest_build % 25 == 0
        break
      end
    end

    repo_id = JSON.parse(open("https://api.travis-ci.org/repos/#{repo}").read)['id']

   (0..highest_build+1).select { |x| x % 25 == 0 }.reverse_each do |last_build|#build_id 不连续，但是after——number连续且25一个分页
     all_builds << paginate_build(last_build, repo_id)
   end
   #all_builds << paginate_build(25, repo_id)
  rescue Exception => e
    error_message = "Retrying, but Error getting Travis builds for #{repo}: #{e.message}"
    puts error_message
    File.open(@error_file, 'a') { |f| f.puts error_message }
    get_travis(repo, build_logs, wait_in_s*2)
    return
  end

  all_builds.flatten!
  # Remove empty entries
  all_builds.reject! { |c| c.empty? }
  # Remove duplicates
  all_builds = all_builds.group_by { |x| x[:build_id] }.map { |k, v| v[0] }
  puts "all_builds.size #{all_builds.size}"
  if all_builds.empty?
    error_message = "Error could not get any repo information for #{repo}."
    puts error_message
    File.open(@error_file, 'a') { |f| f.puts error_message }
    #exit(1)
    return
  end
  
  File.open(json_file, 'w') do |f|
    f.puts JSON.dump(all_builds)
  end

  

end

# if (ARGV[0].nil? || ARGV[1].nil?)
#   puts 'Missing argument(s)!'
#   puts ''
#   puts 'usage: travis_harvester.rb owner repo'
#   exit(1)
# end
def init_method_name
  @inqueue = SizedQueue.new(@thread_num)
  puts "here"
        threads=[]
        @thread_num.times do 
        thread = Thread.new do
            loop do
              puts "get_traviss"
            repo_name = @inqueue.deq
            
            break if repo_name == :END_OF_WORK
            @check_dir = File.join('build_logs/', repo_name.gsub(/\//, '@'))
            if !FileTest::exist?(File.join(@check_dir, 'build_number.json'))
              puts "no json #{repo_name}"
              get_travis repo_name,true
            else
               next

            end
            #(repo_name,true)
            
            
            
            end
            end
            threads << thread
        end
    
        threads
  
end


def method_name
  Thread.abort_on_exception = true
        #threads = init_update_last_build_status2
        
  threads=init_method_name
  repo_name=IO.readlines('repo_name.txt')
  i=0
 # puts repo_name
  repo_name.each do |line|
    
    
      
      
      nameline = JSON.parse(line)
      
      @inqueue.enq nameline
      
    
    #get_travis(line, true)
    #test(line.split('/').first,line.split('/').last)
  end
  @thread_num.times do
    @inqueue.enq :END_OF_WORK
  end
    threads.each {|t| t.join}
    puts "Get Builds Over"
    repo_name.each do |line|
    
    
      
      
        nameline = JSON.parse(line)
        
        repo_name=nameline.gsub(/\//, '@')
        
        process(repo_name)
      #get_travis(line, true)
      #test(line.split('/').first,line.split('/').last)
    end
end
def process(repo_name)
    
    ActiveRecord::Base.clear_active_connections!
    if Build_number.where('repo_name=?',"#{repo_name}").count>1
      puts "have BUILD_NUMBER already"
      return
    else
        @parent_dir = File.join('build_logs/',  "#{repo_name}")
        
      builds = FixSql.load_all_builds(@parent_dir, "build_number.json")
      
      puts "initial_builds.size #{builds.size}"
      #repo_data=Repo_data_travi.new
      builds = builds.reduce([]) do |acc, b|
        unless b[:ended_at].nil?
          #b[:started_at] = Time.parse(b[:started_at])
          acc << b
        else
          acc
        end
      end
      puts "After filtering empty build dates: #{builds.size} builds"
      
      builds.each do |a|

        a[:repo_name]="#{repo_name}"
        
        
      end
      builds = builds.group_by { |x| x[:build_id] }.map { |k, v| v[0] }
      puts "After filtering duplicate build_id: #{builds.size} builds"
      
      ActiveRecord::Base.clear_active_connections!
      begin
        Build_number.import builds,validate: false
        puts 'Repo_data_travis update over'
      rescue
        
      
        
      end

    end
    
    # puts 'Repo_data_travis update over'
    # commitinfo(user,repo1)
end

#test("#{owner}/#{repo}")
method_name
#get_travis("#{owner}/#{repo}", true)
#threerings@tripleplay
#google@guava