module Iterator
$global_arry=[]
def iterate(h,key_val,flag,z)
    if h.is_a?(Hash)
      h.each do |k,v|
        key=k
        value = v 
    
    
        if value.is_a?(Hash) || value.is_a?(Array)||key.is_a?(Hash)||key.is_a?(Array)
          if !key.empty?&&flag==0
            key_val<<key
            
            if value.empty?
              
             z << iterate(key,key_val,1,z)
             
            else
             z << iterate(value,key_val,1,z)
              
            end
    
          elsif value.is_a?(Array)
            key_val<<key 
           z<< iterate(value,key_val,1,z)
          
          else 
           z<< iterate(value,key_val,1,z)
           
          end
    
        
        end
      end
    elsif h.is_a?(Array)
      if h[0].is_a?(String)|| h[0].is_a?(Numeric) 
       temp=key_val.pop
       #puts "ary_key: #{temp} arry_value:#{h}"
       #puts temp.class
       if temp==:commits
        #puts "找到arry"
        #puts "key_val.class:#{key_val.class}"
        puts "key_val.class:#{key_val[0].class}"
        commit_list={
          :now_build_commit=>key_val[0].to_s,
          :commit_list=> h,
          :last_build_commit=>h.last
        }
        #puts commit_list
        $global_arry<<commit_list
        
        end
        
        return $global_arry
      else
        h.each do |a|
         
          z<<iterate(a,key_val,1,z)
         
         
    
    
        
      end
      end
    
    
    
    end
    end