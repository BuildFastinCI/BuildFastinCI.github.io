package main;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStreamReader;
import java.sql.Connection;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.List;

import edu.fdu.se.base.common.Global;
import edu.fdu.se.cldiff.CLDiffLocal;
import javassist.tools.framedump;
import main.SqlCon;
//import sun.tools.jconsole.Worker;
import main.DBConnection;

import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

import org.eclipse.jgit.internal.ketch.KetchReplica.CommitSpeed;

import com.github.javaparser.printer.Printable;
//import com.sun.corba.se.spi.orbutil.threadpool.Work;
import com.sun.tools.javac.code.Type.ForAll;
/**
 * Created by huangkaifeng on 2018/10/11.
 */
public class CLDIFFCmd {
	private String getPath(){
	     return GetRepo.class.getResource("").toString();
	  }
	public static ArrayList<String> commitEach(String commit_list) {
		ArrayList<String> pathname=new ArrayList<String >();
       
        	
        	if(commit_list != null) {
            String substring=commit_list.substring(4,commit_list.length());
            String temp[]=substring.split("\\n");
            
            for(String item:temp) {
            	String tmp_sha=item.substring(2);
            	if (tmp_sha.indexOf("'")!=-1)
            	{
            	tmp_sha=tmp_sha.replaceAll("'", "");
            	}
            	pathname.add(tmp_sha);
            }
            
        	}
        	return pathname;
      }
	
	public static void getInsert(String reponame) throws SQLException, UnsupportedOperationException, IOException {
	    
	    	 
	     
	        System.out.println(reponame);
	   	    String ms1=reponame.toString().split("/")[0];
	   	    String ms2=reponame.toString().split("/")[1];
	   	  
	   	    String localPath = "D:\\javafile\\newrepo\\"+ms1+ms2;
	   	    String url = "https://github.com/"+reponame+".git";
	   	    String repo_name=ms1+"@"+ms2;
	   	    String outputDir = Global.outputdir;
	   	    String repo = "D:/javafile/repo/"+ms1+ms2+"/.git";
 
	   	    DBConnection sqlConnect =new DBConnection();
	   	    ArrayList<ArrayList<String>> result =  new ArrayList<ArrayList<String>>();
	   	    //each_commit
	   	    result = sqlConnect.SqlCon3(repo_name);
	   	    int count=0;
	   	    System.out.println(result.size());
	   	    List<ArrayList<Integer>> insert_cmmt =  new ArrayList<ArrayList<Integer>>();
///**	   	    
			for (ArrayList<String> array : result) {
				
//				if(count<10) {
					System.out.println("count==================:"+count);
					ArrayList<String> each_commit=new ArrayList<String >();
					count+=1;
					 Global.localmiss=0;
				     Global.classchange=0;
				     Global.fieldchange=0;
				     Global.methodbody=0;
				     Global.signature=0;
				     Global.addmethod=0;
				     
				     Global.addclasschange=0;
				     Global.deleteclasschange=0;
				     Global.deletemethod=0; Global.addfieldchange=0;Global.deletefieldchange=0;
				     Global.addmethodbody=0;Global.deletemethodbody=0;Global.addsignature=0;Global.deletesignature=0;Global.addclasschange=0;
				     Global.deleteclasschange=0;
				     Global.deletemethod=0; Global.addfieldchange=0;Global.deletefieldchange=0;
				     Global.addmethodbody=0;Global.deletemethodbody=0;Global.addsignature=0;Global.deletesignature=0;
				     
				     Global.sqlid=array.get(0);
				     Global.repo_name=ms1+"/"+ms2;
				     String commit_list=array.get(1);
				     each_commit=commitEach(commit_list);
//				     System.out.println(each_commit);
				     

				     for (int j=0;j<each_commit.size();j++) {
				    	 
					     Global.last_commit=null;
				    	 Global.now_commit=each_commit.get(j);
				    	 if (j<each_commit.size()-1) {
				    		 Global.last_commit=each_commit.get(j+1); 
				    	 }
				    	 else {
				    		 Global.last_commit=null;
				    	 }
				     
//				     Global.now_commit=array.get(1);
//				     Global.last_commit=array.get(2);
				     
			         
				         System.out.println(ms1 + ms2);
				         if (count==0) {
				         break; 
				         }
				         CLDiffLocal CLDiffLocal = new CLDiffLocal();
	//	 	             CLDiffLocal.run("c5463dd5a182c5c37749b8d5bd33b2b4ebdf1fac","3734f0287ab31c9f0b6eaa912d91e6b3f9f179bb",repo,outputDir);
		     	         
				         CLDiffLocal.run(Global.now_commit,repo,outputDir);
				     }  
//			         CLDiffLocal.run(array.get(1),array.get(2),repo,outputDir);
			         ArrayList<Integer> tmplist=new ArrayList<Integer>();
			             
		        	 tmplist.add(Integer.parseInt(array.get(0)));
			         tmplist.add(Global.signature);
			         tmplist.add(Global.deletesignature);
			         tmplist.add(Global.addsignature);
			         tmplist.add(Global.methodbody);
			         tmplist.add(Global.addmethodbody);
			         tmplist.add(Global.deletemethodbody);
			         tmplist.add(Global.fieldchange);
			         tmplist.add(Global.addfieldchange);
			         tmplist.add(Global.deletefieldchange);
			         tmplist.add(Global.classchange);
			         tmplist.add(Global.addclasschange);
			         tmplist.add(Global.deleteclasschange);
			         tmplist.add(Global.addmethod);
			         tmplist.add(Global.deletemethod);
			        
			         insert_cmmt.add(tmplist);
		         
		         
			        
				     
				     if (count%20==0||count==result.size()) {
				    	 System.out.println("Into threadcall====");
			        	 threadcall(insert_cmmt);
			        	 insert_cmmt.clear();
			         }
				}
//				else {
//					break;
//				}
				     
//			}//将数据处理完
//			**/
			/**
			int total=result.size();
			long starttime=System.currentTimeMillis();
	         int threadcount=20;
	         
	         int batch=total/(threadcount);
			if (total<threadcount) {
				try {
					for (ArrayList<String> array : result) {
						System.out.println("count====:"+count);
					 
						     Global.classchange=0;
						     Global.fieldchange=0;
						     Global.methodbody=0;
						     Global.signature=0;
						     Global.addmethod=0;
						     
//					         System.out.println(array.get(0)+" " +array.get(1)+" "+array.get(2));
					         System.out.println(ms1 + ms2);
					         
					         CLDiffLocal CLDiffLocal = new CLDiffLocal();
//			 	             CLDiffLocal.run("c5463dd5a182c5c37749b8d5bd33b2b4ebdf1fac","3734f0287ab31c9f0b6eaa912d91e6b3f9f179bb",repo,outputDir);
					         ArrayList<Integer> tmplist=new ArrayList<Integer>();
					         tmplist=CLDiffLocal.run(array.get(1),array.get(2),repo,outputDir);
					         
					         if (Global.localmiss==0) {
//					        	 tmplist.add(Integer.parseInt(array.get(0)));
//						         tmplist.add(Global.classchange);
//						         tmplist.add(Global.fieldchange);
//						         tmplist.add(Global.methodbody);
//						         tmplist.add(Global.signature);
//						         tmplist.add(Global.addmethod);
						         
						         insert_cmmt.add(tmplist);
						         count++;
					        
					      
					 }
						
						     
				}
					SqlCon.Insert(insert_cmmt);
				} catch (SQLException e) {
					// TODO Auto-generated catch block
					System.out.println("insert bug");
					e.printStackTrace();
				}
						        	 
						         }
			else {
//			 String outputDir = "D:\\javafile\\cldiff\\result";		        
	         final CountDownLatch latch=new CountDownLatch(threadcount+1);
	         
	         for(int i =0 ;i<threadcount;i++)
	         {
	        	 if ((i+1)*batch<=total) {
	        		 new Thread(new Worker(latch,result.subList(i*batch, (i+1)*batch),i*batch,(i+1)*batch,ms1+ms2,repo,outputDir)).start();
	        	 }
             }
	         if ((threadcount)*batch<total)  {
	        		 new Thread(new Worker(latch,result.subList((threadcount)*batch, total),(threadcount)*batch,total,ms1+ms2,repo,outputDir)).start();
                     
	        	 }
**/			
//			         long starttime=System.currentTimeMillis();
//			         int threadcount=20;
//			         int total=insert_cmmt.size();
//			         int batch=total/(threadcount);
//				     System.out.println("insert_cmmt.size:"+insert_cmmt.size());
//	        
//		       	 
//		        	
//					if (total<threadcount) {
//						try {
//							SqlCon.Insert(insert_cmmt);
//						} catch (SQLException e) {
//							// TODO Auto-generated catch block
//							System.out.println("insert bug");
//							e.printStackTrace();
//						}
//								        	 
//					}
//					else {
//							        
//				         final CountDownLatch latch=new CountDownLatch(threadcount+1);
//				         
//				         for(int i =0 ;i<threadcount;i++)
//				         {
//				        	 if ((i+1)*batch<=total) {
//				        		 Worker threading =new Worker(latch,insert_cmmt.subList(i*batch, (i+1)*batch),i*batch,(i+1)*batch);
//				        		 
////				        		 new Thread(threading).start();
//				        		 Thread thread1 = new Thread(threading);
//				        		 thread1.start();
//				        	 }
//		                 }
//				         if ((threadcount)*batch<total)  {
//				        		 new Thread(new Worker(latch,insert_cmmt.subList((threadcount)*batch, total),(threadcount)*batch,total)).start();
//			                     
//				        	 }
//				        	 
//	        
//				         try {
//				 			latch.await();
//				 			long endTimes = System.currentTimeMillis();
//				 			System.out.println("所有线程执行完毕:" + (endTimes - starttime));
//				 		} catch (InterruptedException e) {
//				 			e.printStackTrace();
//				 		}
//
//					}
			      return;
//
//	        
	        
			         
	       
	      
		
	}
	
	public static void threadcall(List<ArrayList<Integer>> insert_cmmt) {
		 long starttime=System.currentTimeMillis();
         int threadcount=21;
         int total=insert_cmmt.size();
         int batch=total/(threadcount);
	     System.out.println("insert_cmmt.size:"+insert_cmmt.size());

   	 
    	
		if (total<threadcount) {
			try {
				
				SqlCon.Insert(insert_cmmt);
			} catch (SQLException e) {
				// TODO Auto-generated catch block
				System.out.println("insert bug");
				e.printStackTrace();
			}
					        	 
		}
		else {
				        
	         final CountDownLatch latch=new CountDownLatch(threadcount);
	         
	         for(int i =0 ;i<threadcount;i++)
	         {
	        	 if ((i+1)*batch<=total) {
	        		 Worker threading =new Worker(latch,insert_cmmt.subList(i*batch, (i+1)*batch),i*batch,(i+1)*batch);
	        		 
//	        		 new Thread(threading).start();
	        		 Thread thread1 = new Thread(threading);
	        		 thread1.start();
	        	 }
             }
	         if ((threadcount)*batch<total)  {
	        		 new Thread(new Worker(latch,insert_cmmt.subList((threadcount)*batch, total),(threadcount)*batch,total)).start();
                     
	        	 }
	        	 

	         try {
	 			latch.await();
	 			long endTimes = System.currentTimeMillis();
	 			System.out.println("所有线程执行完毕:" + (endTimes - starttime));
	 		} catch (InterruptedException e) {
	 			e.printStackTrace();
	 		}

		}
      return;


	}
 public static void main(String args[]) throws IOException, SQLException{
    Global.runningMode = 0;
    Global.extractmode="each_commit";
    
//    File myPath = new File("D:\\javafile\\cldiff\\result");
    ArrayList<String> reponame=new ArrayList<String>();
//    File f=new File("main/repo_name");
//     
//   	 String path = f.getAbsolutePath();
        String path="D:\\javafile\\cldiff\\CLDIFF\\src\\main\\repo_name.txt";

        try {
       	    BufferedReader bfr = new BufferedReader(new InputStreamReader(new FileInputStream(new File(path)), "UTF-8"));
            String lineTxt = null;
            while ((lineTxt = bfr.readLine()) != null) {
            	System.out.println(lineTxt);
            	reponame.add(lineTxt.split("\"")[1]);
            }

            
            
//            
            bfr.close();
   		
   	} catch (Exception e) {
   		// TODO: handle exception
   		System.out.println(e); 
   	}
     int m=0; 
     for (String object:reponame) {
    	 m=m+1;
    	 if (m<19 ) {
		 continue;
	    }
    	 if(m==24) {
    		 break;
    	 }
    	 Global.outputdir="D:\\javafile\\cldiff\\result";
  
    	 if (m>=12) {
    		 Global.outputdir="E:\\result"; 
    	 }
    	 System.out.println("object===="+object);
    	 for(Connection conn:Global.pools) {
    		 conn.close();
    	 }
    	 if(Global.pools != null && Global.pools.size() > 0){
// 			int last_ind = Global.pools.size();
 			Global.pools.removeAllElements();
    	 }
    	 getInsert(object);
    	 
    	
    	 
     }
     
 
    }   
}
class Worker implements Runnable{
	int start = 0;
	int end = 0;
	
	CountDownLatch latch;
	private List<ArrayList<Integer>> commit_arry;
	private String reponame;
	private String repo;
	private String outputdir;
	public Worker(CountDownLatch latch,List<ArrayList<Integer>> commit_arry,int start,int end) {
		this.commit_arry=commit_arry;
		this.start=start;
		this.end=end;
		this.latch=latch;
		this.reponame=reponame;
		this.repo=repo;
		this.outputdir=outputdir;
	}
	@Override
	public synchronized void run() {
//		for (int i =start;i<end;i++)
//		{
			System.out.println("线程"+Thread.currentThread().getName()+"正在运行");
			try {
//				int count=0;
//				List<ArrayList<Integer>> insert_cmmt =  new ArrayList<ArrayList<Integer>>();
//				for (ArrayList<String> array : commit_arry) {
//					System.out.println("count====:"+count);
//				 
//					     Global.classchange=0;
//					     Global.fieldchange=0;
//					     Global.methodbody=0;
//					     Global.signature=0;
//					     Global.addmethod=0;
//					     
//
//				         String repo = "D:/javafile/repo/"+reponame+"/.git";
//				         CLDiffLocal CLDiffLocal = new CLDiffLocal();
////		 	             CLDiffLocal.run("c5463dd5a182c5c37749b8d5bd33b2b4ebdf1fac","3734f0287ab31c9f0b6eaa912d91e6b3f9f179bb",repo,outputDir);
//				         ArrayList<Integer> tmplist=new ArrayList<Integer>();
//				         tmplist=CLDiffLocal.run(array.get(1),array.get(2),repo,outputdir);
//				         
//				         if (Global.localmiss==0) {
//
//					         
//					         insert_cmmt.add(tmplist);
//					         count++;
//				        
//				      
//				   }
//				}
				SqlCon.Insert(commit_arry);
			} catch (SQLException e) {
				// TODO Auto-generated catch block
				System.out.println("insert bug");
				e.printStackTrace();
			}
//		}
		latch.countDown();
//		return;
	}
}
