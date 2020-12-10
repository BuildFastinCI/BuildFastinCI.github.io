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
load 'lib/csv_helper.rb'

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
        :commit => commit['sha'],
        :pull_req => build['pull_request_number'],
        :branch => commit['branch'],
        # [doc] The build status (such as passed, failed, ...) as returned from the Travis CI API.
        :status => build['state'],
        :message=> commit['message'],
        # [doc] The full build duration as returned from the Travis CI API.
        :duration => build['duration'],
        :started_at => build['started_at'], # in UTC
        :ended_at => build['finished_at'],
        # [doc] The unique Travis IDs of the jobs, in a string separated by `#`.
        :jobs => build['job_ids'],
        
        #:jobduration => build.jobs.map { |x| "#{x.id}##{x.duration}" }
        :event_type => build['event_type'],
        :author_email=>commit['author_email'],
        :committer_email=>commit['committer_email']
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
  json_file = File.join(@parent_dir, 'Repo-data-travis.json')

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

  csv_file = File.join(@parent_dir, 'new_repo-data-travis.csv')
  File.open(csv_file, 'w') do |f|
    f.puts all_builds.first.keys.map { |x| x.to_s }.join(',')
    all_builds.sort { |a, b| b[:build_id]<=>a[:build_id] }.each { |x| f.puts x.values.join(',') }
  end

end

# if (ARGV[0].nil? || ARGV[1].nil?)
#   puts 'Missing argument(s)!'
#   puts ''
#   puts 'usage: travis_harvester.rb owner repo'
#   exit(1)
# end
def init_method_name
  @inqueue = SizedQueue.new(10)
  puts "here"
        threads=[]
        10.times do 
        thread = Thread.new do
            loop do
              puts "get_traviss"
            repo_name = @inqueue.deq
            
            break if repo_name == :END_OF_WORK
            @check_dir = File.join('build_logs/', repo_name.gsub(/\//, '@'))
            if !FileTest::exist?(File.join(@check_dir, 'repo-data-travis.json'))
              puts "no json #{repo_name}"
              get_travis repo_name,true
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
  repo_name=IO.readlines('new_reponame.txt')
  i=0
 # puts repo_name
  repo_name.each do |line|
    
    
      
      
      nameline = JSON.parse(line)
      
      @inqueue.enq nameline
      
    
    #get_travis(line, true)
    #test(line.split('/').first,line.split('/').last)
  end
  10.times do
    @inqueue.enq :END_OF_WORK
  end
    threads.each {|t| t.join}
    puts "Get Builds Over"
end
def test(repos)
  
  
  repository = Travis::Repository.find(repos)
  job=Travis::Job.find(3961020)
  puts job
  #highest_build = repository.last_build_number.to_i
  puts job.number 
  #job=repository.job(1)

  #build.jobs
  #puts "job"
  #puts job.log_id
  last_build=25
  repo_id = JSON.parse(open("https://api.travis-ci.org/repos/#{repos}").read)['id']
  url = "https://api.travis-ci.org/builds?after_number=#{last_build}&repository_id=#{repo_id}"
    STDERR.puts url

    resp = open(url,
                'Content-Type' => 'application/json',
                'Accept' => 'application/vnd.travis-ci.2+json')
    builds = JSON.parse(resp.read)
    #puts "builds_key:#{builds.keys}"
    #puts JSON.pretty_generate(builds)
    builds['builds'].each do |build|
      
      
      puts build
      break
    end
end
owner = ARGV[0]
repo = ARGV[1]
#test("#{owner}/#{repo}")
method_name
#get_travis("#{owner}/#{repo}", true)
#threerings@tripleplay
#google@guava