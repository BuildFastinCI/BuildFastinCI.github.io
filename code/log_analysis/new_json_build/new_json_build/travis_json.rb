require 'csv'
require 'open-uri'
require 'json'
require 'fileutils'
require_relative 'respository'
require_relative 'builds'
require 'travis'
  

module DownloadJSON
  @thread_num=60
  def self.get_job_json(job_id, parent_dir)
    url = "https://api.travis-ci.org/job/#{job_id}"
    count = 0
    j = nil
    begin
      open(url,'Travis-API-Version'=>'3','Authorization'=>'token C-cYiDyx1DUXq3rjwWXmoQ') { |f| j = JSON.parse(f.read) }
    rescue
      puts "Failed to get the job at #{url}: #{$!}"
      j = nil
      count += 1
      message = $!.message
      puts message
      sleep 20 if message.include?('429')
      retry if !message.include?('404') && count<4
    end
    return unless j
    file_name = File.join(parent_dir, "job@#{j['number'].sub(/\./,'@')}.json")

    unless File.size?(file_name)
      File.open(file_name, 'w') do |file|
        file.puts(JSON.pretty_generate(j))
      end
    end
    puts "#Download from #{url} to #{file_name}"
  end

  def self.get_build_json(build_id, parent_dir,jobs_id)
    url = "https://api.travis-ci.org/build/#{build_id}"
    j = nil
    flag=0
    count=0
    begin
      if flag==0
      open(url,'Travis-API-Version'=>'3','Authorization'=>'token C-cYiDyx1DUXq3rjwWXmoQ','Accept'=> 'text/plain') { |f| j = JSON.parse(f.read) }
      
        
      else
        resp = open(url,
          'Content-Type' => 'application/json',
          'Accept' => 'application/vnd.travis-ci.2+json')
        j = JSON.parse(resp.read)
        
      end
    rescue
      puts "Failed to get the build at #{url}: #{$!}"
      flag = flag==0? 1:0
      puts "flag===#{flag}"
      count += 1
      
      message = $!.message
      
      sleep 20 if message.include?('429')
      retry if !message.include?('404') && count<4
     
    end
    #puts JSON.pretty_generate(j)
    if !j.nil?
      file_name = File.join(parent_dir, "build@#{j['number']}.json")
      File.open(file_name,'w') do |file|
        file.puts(JSON.pretty_generate(j))
      end
    end
    puts "#Download from #{url} to #{file_name}"

    # jobs = jobs_id['jobs']
    
    jobs_id.each do |id|
      if  id.is_a?(Hash)
        get_job_json(id['id'], parent_dir)
      else
        get_job_json(id, parent_dir)
      end
    end
    

  end

  def self.get_builds_list(repo_id, offset, parent_dir,highest_build,max_number)
    if offset==0
      while offset
        url = "https://api.travis-ci.org/repo/#{repo_id}/builds?limit=25&offset=#{offset}"
        j = nil
        begin
          open(url,'Travis-API-Version'=>'3','Authorization'=>'token C-cYiDyx1DUXq3rjwWXmoQ') { |f| j = JSON.parse(f.read) }
        rescue
          puts "Failed to get the repo builds list at #{url}: #{$!}"
          sleep 20
          retry
        end
        

        offset = j['@pagination']['next'] ? j['@pagination']['next']['offset'] : nil
        builds = j['builds']
    
        builds.each do |build|
          build_number = build['number']
          file_name = File.join(parent_dir, "build@#{build_number}.json")
          next if File.size?(file_name)
          get_build_json(build['id'], parent_dir,build['jobs'])
        end
        builds = nil
        break
      end  
    else 
      (max_number..highest_build+1).select { |x| x % 25 == 0 }.reverse_each do |last_build|#build_id 不连续，但是after——number连续且25一个分页
        url = "https://api.travis-ci.org/builds?after_number=#{last_build}&repository_id=#{repo_id}"
        j = nil
        begin
          # open(url,'Travis-API-Version'=>'3','Authorization'=>'token C-cYiDyx1DUXq3rjwWXmoQ') { |f| j = JSON.parse(f.read) }
          resp = open(url,
            'Content-Type' => 'application/json',
            'Accept' => 'application/vnd.travis-ci.2+json')
          j = JSON.parse(resp.read)
        rescue
          puts "Failed to get the repo builds list at #{url}: #{$!}"
          sleep 20
          retry
        
        end
        p "======================================"
        p last_build
        
        j['builds'].reverse_each do |build|
          build_number = build['number']
          file_name = File.join(parent_dir, "build@#{build_number}.json")
          next if File.size?(file_name)
          # p build
          p "==================================================="
          p "build_list build id=======#{build['id']}"
          
          
          get_build_json(build['id'], parent_dir,build['job_ids'])
        
      end
      
        
      end
      
      
    end 
  end

  def self.get_repo_id(repo_name, parent_dir,max_number)
    
      
      count=0
      j = nil
      
      
      # get_builds_list(id, 0, parent_dir)
      # puts JSON.pretty_generate(j)
    
    repo_name=repo_name.gsub(/@/,'/')
    repo_slug = repo_name.sub(/\//,'%2F')
    begin
      repository = Travis::Repository.find(repo_name)
      highest_build = repository.last_build_number.to_i
      
      puts "Harvesting Travis build logs for #{repo_name} (#{highest_build-max_number} builds)"
      while true do
        highest_build = highest_build + 1#最近的一次build，也是最大的一次build number 
        if highest_build % 25 == 0
          break
        end
      end
  
      repo_id = JSON.parse(open("https://api.travis-ci.org/repos/#{repo_name}").read)['id']
      get_builds_list(repo_id, 1, parent_dir,highest_build,max_number)
    rescue
      begin
        open("https://api.travis-ci.org/repo/#{repo_slug}",'Travis-API-Version'=>'3','Authorization'=>'token C-cYiDyx1DUXq3rjwWXmoQ') { |f| j = JSON.parse(f.read) }
      rescue
        puts "Failed to get the repo id of #{repo_name}: #{$!}"
        sleep 20
        count += 1
        retry if count<50
        return
      end
      repo_id=j['id']
      get_builds_list(repo_id, 0, parent_dir,0,max_number)
    end
    
      
    
    # puts JSON.pretty_generate(j)
  end

  def self.thread_init
    @queue = SizedQueue.new(@thread_num)  
    threads = []
    @thread_num.times do
      thread = Thread.new do
        loop do
          hash = @queue.deq
          break if hash == :END_OF_WORK
          get_repo_id(hash[:repo_name], hash[:parent_dir],hash[:max_number])
        end
      end
      threads << thread
    end
    threads
  end

  def self.scan_repos(id, builds, stars)
    threads = thread_init
    Build.find_by_sql('SELECT builds.repository_id,max(number) as max_number,repositories.repo_name,star_number as stars FROM builds 
    inner join repositories where repository_id=repositories.id group by repository_id').find_all do |repo|
      #repo是Netflix/SimianArmy这种形式
      # repo_id = repo.repository_id
      repo_name=repo.repo_name
      max_number=repo.max_number
      # p repo.id
      # parent_dir = File.join('..','..','..' 'json_files', repo_name)
      parent_dir = File.expand_path(File.join('..', '..', '..', 'bodyLog2', 
        'json_files',repo_name.gsub(/\//, '@')), File.dirname(__FILE__))
      FileUtils.mkdir_p(parent_dir) unless File.exist?(parent_dir)
      hash = Hash.new
      hash[:repo_name] = repo_name
      hash[:parent_dir] = parent_dir
      hash[:max_number]=max_number
      @queue.enq hash
      puts "Scan project  id=#{repo.repository_id}   #{repo_name} builds=#{repo.max_number}   stars=#{repo.stars}"
    end
    @thread_num.times do
      @queue.enq :END_OF_WORK
    end
    threads.each { |t| t.join }
    puts "Scan Over"
  end

  def self.run
    Thread.abort_on_exception = true
    
    scan_repos(450000, 50, 25)
    
  end  
end

repo_name='ome@bioformats'
repo_name2="swagger-api/swagger-core"

p repo_name
p repo_name=repo_name2.gsub(/@/,'/')
repository = Travis::Repository.find(repo_name2)
  
highest_build = repository.last_build_number.to_i
p highest_build
parent_dir = File.expand_path(File.join('..', '..', '..', 'bodyLog2', 
  'json_files',repo_name.gsub(/\//, '@')), File.dirname(__FILE__))
p parent_dir
build_id=713735672
repo_id=380238
# DownloadJSON.get_builds_list(380238, 300, parent_dir,0,268)
DownloadJSON.run()

