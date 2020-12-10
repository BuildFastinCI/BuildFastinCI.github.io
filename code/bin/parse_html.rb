require 'net/http'
require 'open-uri'
require 'json'
require 'date'
require 'time'
require 'fileutils'
require File.expand_path('../../lib/commit_info.rb',__FILE__)
module ParseHtml
  
  @token = [
    # "623f6c239d614b0c12ed94642815efe39a69d59b",#bad
    "e7ee74749713821a882af6955212ca5926df2889",#bad
    "1e2e6a896a4f081f6cbf8e99003980d36a01153f",#xue
    # "4d37d731bc445de2421f4fbe7bf8ff772ce9af0b",
    "38dbc6ce08b536f86b226afa533e8198f03ccf11",
    "43d40a4f7e730416d7642b727c75674e7b39241b",
    "fbc83d122891cb443b1c5c02cdfd491cd6d8e042"
   
  ]
  $REQ_LIMIT=4990
def self.download_diff(url, wait_in_s = 1)
  if (wait_in_s > 64)
    STDERR.puts "Error: Giveup: We can't wait forever for #{url}"
    return 0
  elsif (wait_in_s > 1)
    sleep wait_in_s
  end

  begin
    begin
      log_url = url
      STDERR.puts "Attempt 1 #{log_url}"
      diff = Net::HTTP.get_response(URI.parse(log_url)).body
      return diff
    rescue
      # Workaround if log.body results in error.
      log_url = url
      STDERR.puts "Attempt 2 #{log_url}"
      diff = Net::HTTP.get_response(URI.parse(log_url)).body
      return diff
    end

    File.open(name, 'w') { |f| f.puts log }
    log = '' # necessary to enable GC of previously stored value, otherwise: memory leak
  rescue
    error_message = "Retrying, but Could not get log #{name}"
    #puts error_message
    
    download_diff(url, wait_in_s*2)
  end
end

def self.github_commit (owner, repo, sha,k)
  
  parent_dir = File.join('commits', "#{owner}@#{repo}")
  commit_json = File.join(parent_dir, "#{sha}.json")
  FileUtils::mkdir_p(parent_dir)

  r = nil
  i=1
  if File.exists? commit_json  
      r= begin
        JSON.parse File.open(commit_json).read
    rescue
      {}
      
    end
    return r if !r.empty?
  end

  unless r.nil? or r.empty?
      return r
    
  else
   

  url = "https://api.github.com/repos/#{owner}/#{repo}/commits/#{sha}"
  #puts "Requesting #{url} "
  
  k=rand(0..$token.size-1)
  contents = nil
  begin
    #puts "begin"
    #puts $token[k]
    puts @token[k]
    r = open(url, 'User-Agent' => 'ghtorrent', 'Authorization' => "token #{$token[k]}")
    
    @remaining = r.meta['x-ratelimit-remaining'].to_i
    #puts "@remaining"
    puts "normal @remaining:#{@remaining}"
    @reset = r.meta['x-ratelimit-reset'].to_i
    contents = r.read
    JSON.parse contents
  rescue OpenURI::HTTPError => e
    @remaining = e.io.meta['x-ratelimit-remaining'].to_i
    @reset = e.io.meta['x-ratelimit-reset'].to_i
    puts  "Cannot get #{url}. Error #{e.io.status[0].to_i}"
    puts "token.size: #{@token.size}"
    puts "token[4]: #{@token[4]}"
    puts "k:#{k}"
    puts "token #{@token}"
    puts "#{@token[k]}:#{@remaining}"
    {}
  rescue StandardError => e
    
    puts "Cannot get #{url}. General error: #{e.message}"
    

    {}
  ensure
    File.open(commit_json, 'w') do |f|
      f.write contents unless r.nil?
      # if r.nil? and 5000 - @remaining >= 6
      #   github_commit(owner, repo, sha,k)
      # end
      f.write '' if r.nil?
      
    
    end
    if !@remaining.nil?
      if 5000 - @remaining >= $REQ_LIMIT
        to_sleep = 500
        puts "Request limit reached, sleeping for #{to_sleep} secs"
        puts "@remaining:#{@remaining}"
        
        puts @token[k]
        sleep(to_sleep)
        if k!=$token.size-1
          k=k+1
        else
          k=0
        end
        github_commit(owner, repo, sha,k)
        #
      end
    end
  end
end
end
end

#puts ParseHtml.download_diff('https://travis-ci.org/structr/structr/jobs/68165554')
