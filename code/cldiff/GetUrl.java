package main;
import java.io.*;
import java.net.HttpURLConnection;
import java.net.MalformedURLException;
import java.net.URL;
import java.net.URLConnection;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.List;

import org.eclipse.jdt.internal.compiler.ast.AND_AND_Expression;

import edu.fdu.se.base.common.Global;
import edu.fdu.se.server.CommitFile;
import main.SqlCon;
//import sun.tools.jconsole.Worker;
import main.DBConnection;
public class GetUrl {
	
	public static List<CommitFile> Get_url(String sha_arry[] ) throws UnsupportedOperationException, IOException, SQLException {
        URL url = null;
        System.out.println("INTO GETURL");
        System.out.println(Global.repo_name);
        
        String repo_name=Global.repo_name;
//        DBConnection con=new DBConnection();
        ArrayList<String> file_path= new ArrayList<String>();
        ArrayList<String> dirctory_path= new ArrayList<String>();
        if (Global.extractmode=="compare"){
        //compare
        file_path=DBConnection.SqlConpath(sha_arry);
        }
        else {
        //each_commit
        System.out.println("Commitinfo====");
        file_path=DBConnection.CommitInfo(sha_arry);
        }
        
//        file_path.add("src/main/java/org/apache/ibatis/executor/loader/javassist/JavassistProxyFactory.java");
//        file_path.add("src/main/java/org/apache/ibatis/executor/loader/javassist/JavassistDeserializationProxy.java");
//       
//        file_path.add("flink-runtime/src/test/java/org/apache/flink/runtime/metrics/groups/OperatorGroupTest.java");
        List <CommitFile> commitFiles =new ArrayList<CommitFile>();
        String basepath="E:\\result\\download\\"+sha_arry[1];
        if (sha_arry[1]==null) {
        	Global.last_commit=Global.parents;
        	sha_arry[1]=Global.last_commit;
        	System.out.println("Global.last_commit==="+Global.last_commit);
        }
        for (String path:file_path ) {
        	
        	
	        	File f=new File(path);
	        	String origin_pathcurr="D:\\javafile\\cldiff\\result\\download\\"+sha_arry[1]+"\\cur\\"+sha_arry[0]+"\\"+path;
	        	String origin_pathprev="D:\\javafile\\cldiff\\result\\download\\"+sha_arry[1]+"\\prev\\"+sha_arry[0]+"\\"+path;
	        	File f_cur=new File(origin_pathcurr);
	        	String path_curr=null;
	        	String path_prev=null;
	        	File f_prev=new File(origin_pathprev);
	        	if (f_cur.exists()) {
	        		 path_curr=origin_pathcurr;
	        	}
	        	else {
	        		 path_curr=Global.outputdir+"\\download\\"+sha_arry[1]+"\\cur\\"+sha_arry[0]+"\\"+path;
	        	}
	        	if (f_prev.exists()) {
	        		 path_prev=origin_pathprev;
	        	}
	        	else {
	        		 path_prev=Global.outputdir+"\\download\\"+sha_arry[1]+"\\prev\\"+sha_arry[0]+"\\"+path;
	        	}
	        	
	            String diffPath=Global.outputdir+"\\download\\"+sha_arry[1]+"\\gen\\"+sha_arry[0]+"\\"+f.getName()+".json";
			    
			    dirctory_path.add(path_curr);
				dirctory_path.add(path_prev);   
				dirctory_path.add(diffPath);  
	//        	File file_cur = new File(path_curr);
	//			File file_prev = new File(path_prev);
				
				
				CommitFile commitFile =new CommitFile();
				commitFile.setCurr_file_path(path_curr);
				commitFile.setPrev_file_path(path_prev);
				commitFile.setBasePath(basepath);
	        	commitFile.setDiffPath(diffPath);
	        	commitFile.setFile_name(path);
	        	commitFile.setParent_commit(sha_arry[0]);
	        	commitFiles.add(commitFile);
        	
        	
//        	commitFile.setFile_name(file_name);
        }
        createFile(dirctory_path);
//        String sha_arry[]= {"1e166433bc9692192a656a2ece646d46dc564831","6ce2e35129c23f0199334cd38b649f21f30cd885"};
       for (int i=0;i<file_path.size();i++) {
    	   int try_flag=0;
           CommitFile file_item=commitFiles.get(i);
           File f2=new File(file_item.getPrev_file_path());
           File f3=new File(file_item.getCurr_file_path());
           if (f2.length()==0 && f3.length()==0) {
        	   try_flag=1;
           }
    	   for(int j=0;j<2;j++) {
//    		   CommitFile file_item=commitFiles.get(i);
    		   String file_string;
	        	if (j==0) {
	        		 file_string=file_item.getCurr_file_path();
//	        		 System.out.println("curfile==="+file_string);
	        	}
	        	else {
	        		 file_string=file_item.getPrev_file_path();
//	        		 System.out.println("prevfile==="+file_string);
	        	}
    		    
	            
//	            System.out.println(repo_name);
	             //鎯宠璇诲彇鐨剈rl鍦板潃
	            //url2 = new URL("https://raw.githubusercontent.com/threerings/tripleplay/550b12f8c75ab7af7c9fe19879585a3a2d335fda/core/src/test/java/tripleplay/ui/ElementTest.java");
	                     //寤虹珛鏂囦欢杈撳嚭娴�
	        	
	        	File f=new File(file_string);
	            BufferedReader in1 =null;
	            HttpURLConnection conn=null;
//	            System.out.println("try_flag==="+try_flag);
//	            if (f.length()<0) {
	            if(!f.exists()||try_flag==1  ) {
	            	System.out.println(f.exists());
	            	
	            	
	            	System.out.println("try_flag"+try_flag);
//	            if(f.length()<0  ){
	            	System.out.println("path==============="+file_string);
			        try {
			        	
			        	  
			        	  
			            
			        	 String urlstring="https://raw.githubusercontent.com/"+repo_name+"/"+sha_arry[j]+"/"+file_path.get(i);
			            System.out.println(urlstring);
			        	url = new URL(urlstring);  
			        	    conn = (HttpURLConnection) url.openConnection(); 
			        	    conn.setRequestMethod("GET"); 
				            conn.setRequestProperty("User-Agent", "Mozilla/4.0 (compatible; MSIE 5.0; Windows NT; DigExt)");
				            InputStream is = conn.getInputStream();
				            // any response?
				            InputStreamReader isr = new InputStreamReader(is);
				            in1 = new BufferedReader(isr);
//				            in1 = new BufferedReader(new InputStreamReader(conn.getInputStream()));
			        	    
			        	    String urlString = "";
				            String current;
				            File fp = new File(file_string);
				            //File fp2 = new File("E:\\study\\commit_file\\%s.java","2");
			                OutputStream os = new FileOutputStream(fp);
				            if((current = in1.readLine()) == null)
				            {
				            	if (j==0) {//curr
				            		file_item.setCurr_file_path(null);
				            	}
				            	else{//prev
				            		file_item.setPrev_file_path(null);
				            	}
				            	
				            }
				            else {
					            while ((current = in1.readLine()) != null) {
					                urlString += current+'\n';
					            }
					            
					            in1.close();
					            os.write(urlString.getBytes());
					            os.close();
					            conn.disconnect();
				            }
			              
			        	
			 
			        } 
			        catch (MalformedURLException e) {
		            e.printStackTrace();
			        } 
			        catch (IOException e) {
////		            e.printStackTrace();
		            System.out.println("add or delete");
		            if (in1 != null) {
	                    in1.close();
	                }
		            if (conn!=null) {
		            	conn.disconnect();
		            }
		            if (j==0) {//curr
	            		file_item.setCurr_file_path(null);
	            		if(!f.exists()) {
	            			f.createNewFile();
	            		}
	            		
	            	}
	            	else{//prev
	            		file_item.setPrev_file_path(null);
	            		if(!f.exists()) {
	            			f.createNewFile();
	            		}
	            	}
		            
		        }
		        finally {
		        	if (conn!=null) {
		            	conn.disconnect();
		            }
		        	
//		            in.close();
		        	if (in1!=null)
		        	{
		        		in1.close();
		        	}
//		            os.close();
				}
		        
				}
//	            in.close()
//	            os.close();
	            
		    }
       }
       
//       int flag=0;
//       flag=Test.Gumtree(file_path);
//       System.out.println(flag);
       return commitFiles;
//       
	}
	public  static void createFile(ArrayList<String> paths){
		   
		 try {
			 for (String path:paths){
				File f = new File(path);
				String cur_path=f.getParent();
//				System.out.println("parent==="+cur_path);
	            f=new File(cur_path);
//	            System.out.println(f.exists());
	            if(!f.exists()){
//	            	System.out.println("==============");
	                f.mkdirs();//创建目录
	            }
			 }
			 }
			catch (Exception e) {
				// TODO: handle exception
				e.printStackTrace();
			
			}
	        finally {
				
			}	
	      
        
    }
	public static List<CommitFile> test_commit(String sha_arry[] ){
		List <CommitFile> commitFiles =new ArrayList<CommitFile>();
		CommitFile commitFile =new CommitFile();
		
		commitFile.setCurr_file_path("D:\\javafile\\cldiff\\result\\download\\298f66c05680bbd51d880358222c5c3c5fbb6fb0\\prev\\b09e1ffa632a0be014a92e9a9a26036665aef79c\\src/com/google/javascript/jscomp/ES6ModuleLoader.java");
		commitFile.setPrev_file_path("D:\\javafile\\cldiff\\result\\download\\298f66c05680bbd51d880358222c5c3c5fbb6fb0\\cur\\b09e1ffa632a0be014a92e9a9a26036665aef79c\\src/com/google/javascript/jscomp/ES6ModuleLoader.java");
		commitFile.setBasePath("D:\\javafile\\cldiff\\result\\download\\298f66c05680bbd51d880358222c5c3c5fbb6fb0");
    	commitFile.setDiffPath("D:\\javafile\\cldiff\\result\\download\\"+sha_arry[1]+"\\gen\\"+sha_arry[0]+"\\"+"ES6ModuleLoader.java"+".json");
    	commitFile.setFile_name("src/com/google/javascript/jscomp/AbstractCommandLineRunner.java");
    	commitFile.setParent_commit(sha_arry[0]);
		commitFiles.add(commitFile);
		return commitFiles;
	}


	public static void main(String[] args) throws UnsupportedOperationException, IOException, SQLException {
		String sha_arry[]= {"150c9cb5b650248ea56cc5356247761a40a3d1df","bda215f4cea76cc4a10c1ac5bc96e8af79a71e09"};
		Global.repo_name="mybatis/mybatis-3";
		Get_url(sha_arry);
	}

}
