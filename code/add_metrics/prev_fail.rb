
require 'tree' 
require File.expand_path('../../lib/travis_torrent.rb',__FILE__)
require File.expand_path('../../lib/within_filepath.rb',__FILE__)

require File.expand_path('../../lib/job.rb',__FILE__)
require File.expand_path('../../lib/pre_pass.rb',__FILE__)
require File.expand_path('../../lib/cll_prevpass.rb',__FILE__)
require File.expand_path('../../lib/cll_prevpasscommit.rb',__FILE__)
require File.expand_path('../../lib/cll_prevfailcommit.rb',__FILE__)
require File.expand_path('../../lib/all_repo_data_virtual_prior_merge.rb',__FILE__) 
require File.expand_path('../../lib/all_repo_data_virtual.rb',__FILE__) 

require File.expand_path('../../lib/travistorrents.rb',__FILE__)
require File.expand_path('../../lib/travis_alldatas.rb',__FILE__)
require File.expand_path('../../lib/travis_82_alldata.rb',__FILE__)
require File.expand_path('../../lib/travis201701.rb',__FILE__)
require File.expand_path('../../lib/travis_1027_alldatas.rb',__FILE__)
require File.expand_path('../../lib/all_repo_data_virtual_prior_merge.rb',__FILE__) 
require 'activerecord-import'
require 'thread'
class PrevFail
    @thread_num=30
    def self.initialize
        $i=0
    end
    def self.init_dodiff
        @inqueue = SizedQueue.new(@thread_num)
        threads=[]
                @thread_num.times do 
                thread = Thread.new do
                    loop do
                    info = @inqueue.deq
                    break if info == :END_OF_WORK
                    DiffWithin.test_diff(info[0],info[1],info[2],info[3],info[4])
                    end
                end
                    threads << thread
                end
        
                threads
    end
    def self.find_last_pass(root,type,count_i)
        # puts "begin processing"
        #root.print_tree
        recurflag=0
        #puts "root.each_leaf #{root.each_leaf.class}"
        tmp_lefarry=[]
        
        tmp_lefarry=root.each_leaf
        
        tmp_lefarry.each do |leaf|
            #puts "root.each_leaf.size #{root.each_leaf.size}"
            # puts "i:===#{i}"
            #puts "leaf.name #{leaf.name}"
            # root.print_tree
            # i=i+1
            flag=1
            #puts leaf.content
            if root.name!=leaf.name#处理叶子节点和跟节点一样的情况,防止无线循环
                # puts "处理leaf"
                unless leaf.content.nil? 
                    if leaf.content["flag"]==0 
                        # puts "已经找到前一次pass"
                        next
                    end
                    if leaf.content["content"].status=='errored' or leaf.content["content"].status=='failed'
                        flag=0
                        leaf.content["flag"] = flag
                        next
                    elsif  leaf.content["content"].status=='canceled' and leaf.content["cancel"]=1
                        flag=0
                        leaf.content["flag"] = flag
                        next
                    else
                        
                        if leaf.content["flag"]!=1
                            # puts"叶子还是fail"
                            leaf.content["flag"] = flag 
                        end 
                        repo_flag=0
                        begin
                            batchs=All_repo_data_virtual_prior_merge.where("build_id<? and repo_name=?",leaf.content["content"].build_id,leaf.content["content"].repo_name).all
                        
                            
                        rescue => exception
                            batchs=All_repo_data_virtual_prior_merge.where("build_id<? and repo_name=?",leaf.content["content"].tr_build_id,leaf.content["content"].gh_project_name.gsub("/","@")).all
                            repo_flag=1
                        end
                        # puts "batchs"
                        if repo_flag==0
                            repo_namem=leaf.content["content"].repo_name
                        else
                            repo_namem=leaf.content["content"].gh_project_name.gsub("/","@")
                        end

                        if batchs.where("now_build_commit=? and repo_name=?",leaf.name,repo_namem).count>0
                            recurflag=1
                            batchs.where("now_build_commit=? and repo_name=?",leaf.name,repo_namem).group("last_build_commit").find_each do |all_repo|
                                    
                                contents=leaf.content
                                contents["depth"]=contents["depth"]+1
                                contents["content"]=all_repo
                                leaf << Tree::TreeNode.new(all_repo.last_build_commit,contents )
                                #puts "all_repo.last_build_commit #{all_repo.last_build_commit}"   
                            end
                        else
                            bach=Travistorrent_822017_alldatas.where("git_trigger_commit=?",leaf.name).all
                            if bach.count!=0
                                recurflag=1
                                contents=leaf.content
                                contents["depth"]=contents["depth"]+1
                                contents["content"]=bach.first
                                leaf << Tree::TreeNode.new(bach.first.git_prev_built_commit,contents )
                                    # leaf << Tree::TreeNode.new(bach.first.git_prev_built_commit,[bach.first] )
                                

                            else
                                batchs=Travistorrent_11_1_2017datas.where("gh_project_name=?",repo_namem.gsub("@","/"))
                                bach=batchs.where("git_trigger_commit=?",leaf.name)
                                if bach.count!=0
                                    recurflag=1
                                    contents=leaf.content
                                    contents["depth"]=contents["depth"]+1
                                    contents["content"]=bach.first
                                    leaf << Tree::TreeNode.new(bach.first.git_prev_built_commit,contents )
                                        # leaf << Tree::TreeNode.new(bach.first.git_prev_built_commit,[bach.first] )
                                    
    
                                else
                                    bach=Travistorrent_1027_alldatas.where("git_commit=?",leaf.name)
                                    if bach.count!=0
                                        recurflag=1
                                        contents=leaf.content
                                        contents["depth"]=contents["depth"]+1
                                        contents["content"]=bach.first
                                        leaf << Tree::TreeNode.new(bach.first.git_commits.split('#').last,contents )
                                            # leaf << Tree::TreeNode.new(bach.first.git_prev_built_commit,[bach.first] )
                                        
        
                                    else
                                        bach=Travistorrent_alldatas.where("git_trigger_commit=?",leaf.name)
                                        if bach.count!=0
                                            recurflag=1

                                            contents=leaf.content
                                            contents["depth"]=contents["depth"]+1
                                            contents["content"]=bach.first
                                            leaf << Tree::TreeNode.new(bach.first.git_prev_built_commit,contents )
                                                # leaf << Tree::TreeNode.new(bach.first.git_prev_built_commit,[bach.first] )
                                        else 
                                            bach=All_repo_data_virtual.where("commit=?",leaf.name).first
                                            if !bach.nil?
                                                if bach.status=='canceled'
                                                    leaf.content["cancel"]=1

                                                end
                                            
                                            end    
                                        end
                                    end
                                end




                            end
                        
                        end
                    end
                end
            end
        end
        lenth=root.each_leaf.size
        if recurflag==1  and count_i<6000
            # count=0
            # max_depth=0
            # root.each_leaf do |leaf|
                        
            # unless leaf.content.nil?
            #     if leaf.node_depth >= 2
            #         count+=1
            #         if leaf.node_depth>max_depth
            #             max_depth=leaf.node_depth
            #         end
                
            #     end
            #     if leaf.node_depth>50
            #         leaf.content << "stop"
            #     end
                
            # end
            # end
            # if (a=count- 2**(max_depth-1))>0
            
            #     i=0
            #     root.each_leaf do |leaf|
            #         if i<a
                        
            #                 leaf.content << "stop"
                            
            #                 i+=1
                        
                        
            #         end     
            
            #     end


            # end
            arry1=root.each_leaf
            root.remove_all!
            
            arry1=arry1.group_by { |x| x.name }.map { |k, v| v[0] }
            arry1.each do |leaf|
                
              root.add(leaf)
                # root_node << Tree::TreeNode.new(n[i],m[i])
                # puts root_node.each_leaf.size
                # i=i+1
                
            end
                        
            # arry1=[]
            # arry1=root.each_leaf
            
            # puts "递归 ==================#{count_i}"
            
            # #sleep 2000
            # root.remove_all!
            # arry1=arry1.group_by { |x| x.name }.map { |k, v| v[0] }
            # arry1.each do |leaf|

            #     root.add(leaf)
            #     # root_node << Tree::TreeNode.new(n[i],m[i])
            #     # puts root_node.each_leaf.size
            #     # i=i+1
                
            # end
            count_i+=1
            find_last_pass(root,type,count_i)
        else
        puts "==============done!"
        leaf_arry=[]
        depth_arry=[]
        cancel_flags=[]
        root.each_leaf do |leaf|
            
            unless leaf.content.nil?
                if leaf.content["flag"]==0
                    puts  leaf.name
                    leaf_arry << leaf.name
                    depth_arry << leaf.content["depth"]
                    cancel_flags<< leaf.content["cancel"]     
                end
                
            end
        end
        leaf_arry.uniq!
        #puts "leaf_arry#{leaf_arry}"
        #sleep 2000
                if type=='within'
                    # leaf_arry.each do |last_pass|
                       # @inqueue.enq [@user,@repo,last_pass,root.name,2]
                       
                       cll_prevpasscommits
                        DiffPrev.test_diff(@user,@repo,leaf_arry,root.name,2,type)

                    # end
                else
                    
                        if !(leaf_arry.empty? or leaf_arry.nil?)
                            today = Time.new; 
                            acc={:repo_name=>@user+'@'+@repo,:git_commit=>root.name,:prev_passcommits=>leaf_arry,:gap_num=>depth_arry,:cancel_flag=>cancel_flags,:insert_time=>today.strftime("%Y-%m-%d %H:%M:%S")}
                            record=Cll_prevfailcommit.new(acc)
                            record.save
                             #ActiveRecord::Base.clear_active_connections!
                        end
                       
                    # end
                end
        end

        # @thread_num.times do   
        # @inqueue.enq :END_OF_WORK
        # end
        # threads.each {|t| t.join}
        # puts "TODIFFUpdate Over"
    end
    def self.init_prev_pass
        @queue = SizedQueue.new(@thread_num)
        threads=[]
        mutex = Mutex.new
        puts "in prev"
        @thread_num.times do
                thread = Thread.new do
                    loop do
                    info = @queue.deq
                    break if info == :END_OF_WORK
                    # builds=[]
                    # items=[]
                    #puts "#{@user}@#{@repo}"
                    # if info[1]=='wihtin'
                    #     if Prev_passed.where("git_commit=?",info[0]).count>0
                    #         next
                    #     end
                    # else
                        
                    # if info[0]=='8bc1734431e2fe93da57f1a168ec2dc7bd1a211a'
                        
                    #     next
                        
                    # end
                    # end
                    #@thread_num.times do 
                    #mutex.lock
                    root_node=Tree::TreeNode.new(info[0])
                    All_repo_data_virtual_prior_merge.where("now_build_commit=? and repo_name=?",info[0],"#{@user}@#{@repo}").group("last_build_commit").find_each do |all_repo|
                        #info.pre_builtcommit
                        #puts "all_rpeo.id#{all_repo.id}"
                        #puts "all_repo.last_build_commit #{all_repo.last_build_commit}"
                        root_node << Tree::TreeNode.new(all_repo.last_build_commit,{"content"=>all_repo,"depth"=>1,"flag"=>1,"cancel"=>0})
                        
                    end
                    
                       #@queue2.enq [root_node,info[1]]
                    #root_node.print_tree
                    #puts root_node
                    puts info[0]
                    find_last_pass(root_node,info[1],0)
                    #mutex.unlock
                    
                    
                    
                    
                    
                    end
                end
                    threads << thread
                end
        
                threads 
        
    end
    

    def self.cll_prevpass(user,repo)
        #ActiveRecord::Base.clear_active_connections!
        @user=user
        @repo=repo
        Thread.abort_on_exception = true
        all_repo_data_virtualarry=[]
        cll_prevfailarry=[]
        info=All_repo_data_virtual_prior_merge.where("repo_name=? and gh_team_size is not null","#{@user}@#{@repo}").order("now_build_id asc").first
        first_id=info.now_build_id
        p first_id
        last_info=All_repo_data_virtual_prior_merge.where("repo_name=? and gh_team_size is not null","#{@user}@#{@repo}").order("now_build_id asc").last
        
        last_id=last_info.now_build_id
        p last_id
        All_repo_data_virtual_prior_merge.where("repo_name=? and last_label=1 and now_build_id>=? and now_build_id<=?","#{user}@#{repo}",first_id,last_id).group("commit").find_each do |info|
            all_repo_data_virtualarry<< info.last_build_commit
        #Withinproject.where("pre_builtcommit=?","f20692facf4c00bcafc26908fb51bde98ab45562").find_each do |info|
        end
        all_repo_data_virtualarry.uniq!
        Cll_prevfailcommit.where("repo_name=?","#{user}@#{repo}").find_each do |item|
            cll_prevfailarry << item.git_commit
        end
        cll_prevfailarry.uniq!
        tmp=all_repo_data_virtualarry-cll_prevfailarry
        
        puts "tmp #{tmp.size}"
        threads = init_prev_pass
        #@queue.enq ['8d71c34f73be60d97f1a85063b447012c8f44517','cll']#测试有merge的情况是导致last_build_commit的build时间时间晚于now_build_commit,且build_id>now_build,这种情况就没有把这个父commit加进去
        for commit in tmp do
          @queue.enq [commit,'cll']
       
        end
        @thread_num.times do   
        @queue.enq :END_OF_WORK
        end
        threads.each {|t| t.join}
        puts "TreeUpdate Over"
        ActiveRecord::Base.clear_active_connections!
        return
        #threads.each {|t| puts t.status}
        
    end

    def self.prev_diff(user,repo)
        @user=user
        @repo=repo
        Thread.abort_on_exception = true
        threads = init_prevdiff
        cll_prevpassed_arry=[]
        cll_prevpasscommit_arry=[]
        Cll_prevpassed.where("repo_name=?","#{user}@#{repo}").find_each do |info|
            cll_prevpassed_arry << info.git_commit
        end

        Cll_prevpasscommit.where("repo_name=?","#{user}@#{repo}").find_all do |info|
            cll_prevpasscommit_arry << info.git_commit

        end
        left_commit=cll_prevpasscommit_arry-cll_prevpassed_arry
        for item in left_commit
            Cll_prevpasscommit.where("git_commit=?",item).find_each do |info|
                @inqueue.enq info
            end
        end
        @thread_num.times do   
            @inqueue.enq :END_OF_WORK
        end
            threads.each {|t| t.join}
            #threads.each {|t| puts t.status}
        puts "PathUpdate Over"
        ActiveRecord::Base.clear_active_connections!
        #ActiveRecord::Base.connection.close
        #threads.each {|t| puts t.status}
        return
    end
     
    
      
    
    
    def self.run()
        parent_dir = File.expand_path('../../repo_name.txt',__FILE__)
        repo_name=IO.readlines(parent_dir)
        i=0
        repo_name.each do |line|
            line = JSON.parse(line)
            puts line
            @user = line.split('/').first
            @repo = line.split('/').last
            @parent_dir = File.join('build_logs/',  "#{@user}@#{@repo}")
            #if i>=11
            # process(line.split('/').first,line.split('/').last)
            #commitinfo(@user,@repo)
            ActiveRecord::Base.clear_active_connections!
            if i >=0
                
                PrevFail.cll_prevpass(@user,@repo)
                #build_state_threads(line.split('/').first,line.split('/').last)
                
                i+=1
            else
                i+=1
            end
            
            #else
            #  i+=1
        end
    end
end

PrevFail.run()
# bach=Travistorrent_822017_alldatas.where("git_trigger_commit=?",'a6ba9146455466e715fd13582247e3008e0eb58d').all
# bach.find_all do |m|
#     puts m

# end
# batchs=All_repo_data_virtual_prior_merge.where("id<20950 and repo_name=?","structr@structr").all
# p batchs.where("build_id=?",33333).count
