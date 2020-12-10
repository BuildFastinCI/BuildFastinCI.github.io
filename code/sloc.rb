
 require File.expand_path('../lib/build.rb',__FILE__)
 require 'csv'
  def write_file(contents,json_file)
    # json_file = File.join(parent_dir, filename)
    if contents.class == Array
      
        contents.flatten!
    
    end
    if File.exists? json_file
      
      puts "initial builds size #{contents.size}"
      if contents.empty?
        error_message = "Error could not get any repo information for ."
        puts error_message    
        
      end
    
      File.open(json_file, 'w') do |f|
      f.puts JSON.dump(contents)
      end
    
     else
      File.open(json_file, 'w') do |f|
      f.puts JSON.dump(contents)
      end
    end

      
  end
  def self.init_cal_sloc
    @queue = SizedQueue.new(@thread_number)
    threads=[]
            @thread_number.times do 
            thread = Thread.new do
                loop do
                info = @queue.deq
                break if info == :END_OF_WORK
                checkout_dir =File.expand_path(File.join('..','..','sequence', 'repository', info[0]+'@'+ info[1]),File.dirname(__FILE__)) 
                        # puts checkout_dir
                        cmd = "cd #{checkout_dir} && cloc --vcs git "
                        value = `#{cmd}`
                        regex = /Java\s+\d+\s+\d+\s+\d+\s+(\d+)/
                        result = nil
                        mm=-1
                        value.lines.each do |line|
                            result = regex.match(line)
                            if !result.nil? 
                                break
                            end
                        end
                        if !result.nil?
                            single_sloc={:repo_id => info[2],info[2]=>result[1]}
                            
                        else
                            single_sloc={:repo_id => info[2],info[2] => mm}
                        
                        
                        
                        end 
                        $sloc_hash << single_sloc 
                end
            end
                threads << thread
            end
    
            threads
    
  end
  def run
    i=0
    repo_sloc=[]
    $sloc_hash=[]
    @thread_number=60
    csv_file = File.join('./test_code','repo_sloc_small.csv')
    Thread.abort_on_exception = true
    threads = init_cal_sloc
    
    diff_arry=[]
    CSV.foreach 'slow_build_trend.csv' do |row|
        if i==0
            i=i+1
            next
        else
            # puts row.class #=> Array
            
                puts row[2].to_i
                item=Build.where("repository_id=?",row[2].to_i).first
                user=item.repo_slug.split('/')[0]
                repo=item.repo_slug.split('/')[1]
                @queue.enq [user,repo,row[2].to_i]
                i=i+1
            
        end
    end
    
    @thread_number.times do   
    @queue.enq :END_OF_WORK
    end
    threads.each {|t| t.join}
    puts "Update Over"
    # CSV.foreach 'slow_build_trend.csv' do |row|
    #     if i==0
    #         i=i+1
    #         next
    #     else
    #         # puts row.class #=> Array
            
    #         puts row[2].to_i
    #         item=Build.where("repository_id=?",row[2].to_i).first
    #         user=item.repo_slug.split('/')[0]
    #         repo1=item.repo_slug.split('/')[1]
    #         # puts user
    #         # puts repo1
    #         # break
    #         checkout_dir =File.expand_path(File.join('..','..','sequence', 'repository', user+'@'+ repo1),File.dirname(__FILE__)) 
    #         # puts checkout_dir
    #         cmd = "cd #{checkout_dir} && cloc --vcs git "
    #         value = `#{cmd}`
    #         regex = /Java\s+\d+\s+\d+\s+\d+\s+(\d+)/
    #         result = nil
    #         mm=-1
    #         value.lines.each do |line|
    #             result = regex.match(line)
    #             if !result.nil? 
    #                 break
    #             end
    #         end
    #         if !result.nil?

    #             repo_sloc <<  result[1]
    #         else
    #             repo_sloc << mm
            
            
            
    #         end
    #         puts repo_sloc
           
            
    #     end
    #   end

      CSV.open(csv_file, "wb",
        :write_headers=> true,
        :headers => ["repo_id","sloc"]
          ) do |csv|
            $sloc_hash.each do |row|
             csv << row.values
          end
        end
        json_file=File.join('./test_code', 'sloc_file.json')
        write_file($sloc_hash,json_file)
    # CSV.read('slow_build_trend.csv').each do |row|
    #     puts row.class
    #     puts row[0]
    #     break

    # end
      
    
  end
  run