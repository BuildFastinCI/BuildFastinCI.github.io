package edu.fdu.se.cldiff;

import com.github.gumtreediff.tree.Tree;
import com.github.javaparser.printer.Printable;
import com.github.javaparser.utils.SourceRoot.Callback.Result;
import com.google.gson.GsonBuilder;
import com.sun.deploy.security.CeilingPolicy;
import com.sun.org.apache.bcel.internal.generic.INSTANCEOF;
import com.sun.xml.internal.ws.util.xml.CDATA;

import edu.fdu.se.base.common.FilePairData;
import edu.fdu.se.base.common.Global;
import edu.fdu.se.base.links.FileInnerLinksGenerator;
import edu.fdu.se.base.links.FileOuterLinksGenerator;
import edu.fdu.se.base.links.TotalFileLinks;
import edu.fdu.se.base.links.similarity.TreeDistance;
import edu.fdu.se.base.miningchangeentity.ChangeEntityData;
import edu.fdu.se.base.miningchangeentity.base.ChangeEntity;
import edu.fdu.se.base.miningchangeentity.base.ChangeEntityDesc;
import edu.fdu.se.base.miningchangeentity.base.StatementPlusChangeEntity;
import edu.fdu.se.base.miningchangeentity.member.ClassChangeEntity;
import edu.fdu.se.base.miningchangeentity.member.FieldChangeEntity;
import edu.fdu.se.base.miningchangeentity.member.InitializerChangeEntity;
import edu.fdu.se.base.miningchangeentity.member.MethodChangeEntity;
import edu.fdu.se.base.miningchangeentity.statement.ConstructorInvocationChangeEntity;
import edu.fdu.se.base.miningchangeentity.statement.SuperConstructorInvocationChangeEntity;
import edu.fdu.se.base.preprocessingfile.data.FileOutputLog;
import edu.fdu.se.fileutil.FileUtil;
import edu.fdu.se.server.Meta;
import main.GetUrl;
import edu.fdu.se.server.CommitFile;
import org.eclipse.jgit.internal.storage.file.GlobalAttributesNode;
import org.graalvm.compiler.java.GraphBuilderPhase.Instance;
import org.w3c.dom.CDATASection;

import java.io.File;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.sql.SQLException;
import java.util.*;

/**
 * Created by huangkaifeng on 2018/4/12.
 */
public class CLDiffAPI {

    private Map<String, ChangeEntityData> fileChangeEntityData = new HashMap<>();
    public CLDiffCore clDiffCore;
    private List<FilePairData> filePairDatas;

    /**
     * output path +"proj_name" + "commit_id"
     *
     * @param outputDir
     * @throws SQLException 
     * @throws IOException 
     * @throws UnsupportedOperationException 
     */
    public CLDiffAPI(String outputDir, Meta meta) throws UnsupportedOperationException, IOException, SQLException {
//        Global.outputFilePathList = new ArrayList<>();
    	
    	System.out.println("into the cldiffapi===========\n");
    	System.out.println("now_commit===========\n"+Global.now_commit);
    	System.out.println("Global.localmiss=========="+Global.localmiss);
        filePairDatas = new ArrayList<>();
        clDiffCore = new CLDiffCore();
        clDiffCore.mFileOutputLog = new FileOutputLog(outputDir, meta.getProject_name());
        
        
        if (Global.localmiss==0) {
        	
        	clDiffCore.mFileOutputLog.setCommitId(meta.getCommit_hash(), meta.getParents());
        	initDataFromJson(meta);
        }
        else {
        	System.out.println("geturl============");
        	String sha_array[]= {Global.now_commit,Global.last_commit};
//        	GetUrl getUrl =new GetUrl();
        	List<CommitFile> commitFiles=GetUrl.Get_url(sha_array);
        	List<String> missparents=new ArrayList<String>();
        	missparents.add(Global.parents);
        	meta.setParents(missparents);
        	clDiffCore.mFileOutputLog.setCommitId(meta.getCommit_hash(), meta.getParents());
        	initDataFromJson(commitFiles);
        }
//        FileUtil.createFile("meta.json", new GsonBuilder().setPrettyPrinting().create().toJson(meta), new File(clDiffCore.mFileOutputLog.metaLinkPath));
    }
    
    public void initDataFromJson(List<CommitFile> commitFiles) {
    	if(commitFiles!=null) {
	        for (int i = 0; i < commitFiles.size(); i++) {
	            CommitFile file = commitFiles.get(i);
	            if (file.getDiffPath() == null) {
	                continue;
	            }
	            
	            String fileFullName = file.getFile_name();
	            int index = fileFullName.lastIndexOf("/");
	            String fileName = fileFullName.substring(index + 1, fileFullName.length());//文件名
	            
	            String prevFilePath = file.getPrev_file_path();
//	            System.out.println("prevFilePath:=="+prevFilePath);
	            String currFilePath = file.getCurr_file_path();
//	            System.out.println("currFilePath:=="+currFilePath);
	            String parentCommit = file.getParent_commit();
//	            System.out.println("parentCommit:=="+parentCommit);
	            String basePath = file.getBasePath();
	            Global.basepath=basePath;
//	            System.out.println("basePath:=="+basePath);
//	            System.out.println("diffPath:=="+file.getDiffPath());
	            
	            byte[] prevBytes = null;
	            byte[] currBytes = null;
	            try {
	                if (prevFilePath != null) {
	                    prevBytes = Files.readAllBytes(Paths.get(prevFilePath));
//	                    System.out.println("prevBytesxx:"+Paths.get(prevFilePath));
	                    
	                }
	                if (currFilePath != null) {
	                    currBytes = Files.readAllBytes(Paths.get(currFilePath));
//	                    System.out.println("currBytesxx:"+Paths.get(currFilePath));
	                }
	            } catch (Exception e) {
	                e.printStackTrace();
	            }
	            FilePairData fp = new FilePairData(prevBytes, currBytes, prevFilePath, currFilePath, fileName);
	            fp.setParentCommit(parentCommit);
	            filePairDatas.add(fp);
        }
		}
    	
    }
    public void initDataFromJson(Meta meta) {
    	System.out.println("initDataFromJson===========\n");
        List<CommitFile> commitFiles = meta.getFiles();
        List<String> actions = meta.getActions();
//		System.out.println("commitFiles: "+commitFiles);
		if(commitFiles!=null) {
	        for (int i = 0; i < commitFiles.size(); i++) {
	            CommitFile file = commitFiles.get(i);
	            if (file.getDiffPath() == null) {
	            	System.out.println("getDiffPath: "+file.getDiffPath() );
	                continue;
	            }
	            String action = actions.get(i);
	            String fileFullName = file.getFile_name();
	            int index = fileFullName.lastIndexOf("/");
	            String fileName = fileFullName.substring(index + 1, fileFullName.length());//文件名
	            
	            String prevFilePath = file.getPrev_file_path();
//	            System.out.println("prevFilePath:=="+prevFilePath);
	            String currFilePath = file.getCurr_file_path();
//	            System.out.println("currFilePath:=="+currFilePath);
	            String parentCommit = file.getParent_commit();
//	            System.out.println("parentCommit:=="+parentCommit);
	            String basePath = clDiffCore.mFileOutputLog.metaLinkPath;
//	            System.out.println("basePath:=="+basePath);
//	            System.out.println("diffPath:=="+file.getDiffPath());
	            
	            byte[] prevBytes = null;
	            byte[] currBytes = null;
	            try {
	                if (prevFilePath != null) {
	                    prevBytes = Files.readAllBytes(Paths.get(basePath + "/" + prevFilePath));
//	                    System.out.println("prevBytes:"+Paths.get(basePath + "/" + prevFilePath));
	                }
	                if (currFilePath != null) {
	                    currBytes = Files.readAllBytes(Paths.get(basePath + "/" + currFilePath));
//	                    System.out.println("currBytes:"+Paths.get(basePath + "/" + currFilePath));
	                }
	            } catch (Exception e) {
	                e.printStackTrace();
	            }
	            FilePairData fp = new FilePairData(prevBytes, currBytes, basePath + "/" + prevFilePath, basePath + "/" + currFilePath, fileName);
	            fp.setParentCommit(parentCommit);
	            filePairDatas.add(fp);
        }
		}
    }


    public void generateDiffMinerOutput() {
    	String absolutePath;
    	if (Global.localmiss==0) {
    		 absolutePath = this.clDiffCore.mFileOutputLog.metaLinkPath;
    	}
    	else {
    		 absolutePath=Global.basepath;
    		
    	}
        Global.changeEntityFileNameMap = new HashMap<>();
        int count=0;
        ArrayList<Integer> result=new ArrayList<Integer>();
       
    	
        for (FilePairData fp : filePairDatas) {
        	
        	
        	
//        	if (!fp.getFileName().equals("GroupTest.java")) {
//        		continue;
//        	}
//        		
        	
            Global.parentCommit = fp.getParentCommit();
            System.out.println("filename:=="+fp.getFileName());
            System.out.println(Global.now_commit);
//            System.out.println("current:=="+fp.getCurr());
            Global.fileName = fp.getFileName();
            if (fp.getPrev() == null && fp.getCurr() == null) {
            	
                continue;
            }
            if (fp.getPrev() == null) {
                this.clDiffCore.dooAddFile(fp.getFileName(), fp.getCurr(), absolutePath);
            } else if (fp.getCurr() == null) {
                this.clDiffCore.dooRemoveFile(fp.getFileName(), fp.getPrev(), absolutePath);
            } else {
                this.clDiffCore.dooDiffFile(fp.getFileName(), fp.getPrev(), fp.getCurr(), absolutePath);
            }
            //compare mode insert 和delete is opposite
            //each mode insert and delete is same as ce.tostring
            try {
            	
            	for (ChangeEntity ce:this.clDiffCore.changeEntityData.mad.getChangeEntityList())
                {
            		
                	System.out.println(ce);
//                	System.out.println("cd====="+ce.getStageIIBean().getThumbnail());
            		if (ce instanceof MethodChangeEntity)
                	{
//            			System.out.println("methood change========");
//            			if(ChangeEntityDesc.StageIISub.SUB_SIGNATURE.equals(ce.getStageIIBean().getThumbnail())){
//            				 //+1 signature
//            				System.out.println("hkf signature");
//            			}
            	           
            		    
            				
            			if (ce.getStageIIBean().getThumbnail()==null) {
            			
            				
            					if (ce.toString().indexOf("Insert")!=-1) {
            						System.out.println("addsignature====");
	            					Global.addsignature+=1;
	            					
	            				}
	            				else if (ce.toString().indexOf("Delete")!=-1) {
	            					System.out.println("deeltesignature====");
	            					Global.deletesignature+=1;
	            					
								}
	            				else {
	            					System.out.println("signature====");
	            					Global.signature+=1;
								}
            					
            				
            				
            			}	
	//            				signature+=1;
	            			
	            		
                            
            			else {
//            				System.out.println("addnewmethod========");
            				
            					if (ce.toString().indexOf("Insert")!=-1) {
                					
                					System.out.println("addnewmethod======");
                					Global.addmethod+=1;
                					
                				}
                				if (ce.toString().indexOf("Delete")!=-1) {
                					System.out.println("deletenewmethod======");
                					Global.deletemethod+=1;
                				}
            					
            				
//            				addmethod+=1;
            			}
            				
                        
                	}
                	if (ce instanceof ConstructorInvocationChangeEntity) {
                		System.out.println("override===");
                	}
                	if(ce instanceof SuperConstructorInvocationChangeEntity) {
                		System.out.println("superoverride===");
                	}
                	if(ce instanceof InitializerChangeEntity) {
                		System.out.println("superoverride===");
                	}
                	
                	if(ce instanceof StatementPlusChangeEntity) {
//                		String location=ce.stageIIBean.getLocation();
//                		System.out.println("methodbody:=========");
//                		System.out.println("ce.getgetGranularity()======"+ce.getStageIIBean().getGranularity());
//            			System.out.println("ce.getThumbnail======"+ce.getStageIIBean().getThumbnail());
//            			System.out.println("SUB_DECLARATION======"+ChangeEntityDesc.StageIISub.SUB_SIGNATURE);
                		
                		
                			if (ce.toString().indexOf("Insert")!=-1) {
                				System.out.println("addmethodbody====");
	        					Global.addmethodbody+=1;
	        					
	        				}
	        				else if (ce.toString().indexOf("Delete")!=-1) {
	        					System.out.println("deltemethodbody====");
	        					Global.deletemethodbody+=1;
							}
	        				else {
	        					System.out.println("methodbody====");
	        					Global.methodbody+=1;
							}
                		
                		
//                		methodbody+=1;
                				
                		
                	}
                	if (ce instanceof FieldChangeEntity) {
//                		System.out.println("FieldChangeEntity:===========");
//                		System.out.println("ce.getgetGranularity()======"+ce.getStageIIBean().getGranularity());
//            			System.out.println("ce.getThumbnail======"+ce.getStageIIBean().getThumbnail());
//            			System.out.println("SUB_DECLARATION======"+ChangeEntityDesc.StageIISub.SUB_SIGNATURE);
                		
                		
                			if (ce.toString().indexOf("Insert")!=-1) {
                				System.out.println("addfieldchange====");
	        					Global.addfieldchange+=1;
	        					
	        				}
	        				else if (ce.toString().indexOf("Delete")!=-1) {
	        					System.out.println("deltefieldchange====");
	        					Global.deletefieldchange+=1;
							}
	        				else {
	        					System.out.println("fieldchange====");
	        					Global.fieldchange+=1;
							}
                		
                		
//                		fieldchange+=1;
                	}
                	if (ce instanceof ClassChangeEntity) {
//                		System.out.println("ClassChangeEntity:============");
//                		System.out.println("ce.getgetGranularity()======"+ce.getStageIIBean().getGranularity());
//            			System.out.println("ce.getThumbnail======"+ce.getStageIIBean().getThumbnail());
//            			System.out.println("SUB_DECLARATION======"+ChangeEntityDesc.StageIISub.SUB_SIGNATURE);
                		
                		
                			if (ce.toString().indexOf("Insert")!=-1) {
                				System.out.println("addclasschange====");
	        					Global.addclasschange+=1;
	        					
	        				}
	        				else if (ce.toString().indexOf("Delete")!=-1) {
	        					System.out.println("delteclasschange====");
	        					Global.deleteclasschange+=1;
							}
	        				else {
	        					System.out.println("classchange====");
	        					Global.classchange+=1;
							}
                			
                		
//                		     Global.classchange+=1;
//                		classchange+=1;
                	}
//                	this.fileChangeEntityData.put(fp.getParentCommit() + "@@@" + this.clDiffCore.changeEntityData.fileName, this.clDiffCore.changeEntityData);
                	
                }
//            	this.clDiffCore.changeEntityData.mad.getChangeEntityList().clear();;
			} catch (Exception e) {
				// TODO: handle exception
			}
//            System.out.println("changeEntitylist:"+(this.clDiffCore.changeEntityData));
//            System.out.println("changeEntitylist:"+this.clDiffCore.changeEntityData.mad.getChangeEntityList().get(0).getClass().toString());
        	
            	
            		
            		
        	
        	
        } 
//         break;   
            
//        
//        
//        
//        List<String> fileNames = new ArrayList<>(this.fileChangeEntityData.keySet());
//        TotalFileLinks totalFileLinks = new TotalFileLinks();
//        for (int i = 0; i < fileNames.size(); i++) {
//            String fileNameA = fileNames.get(i);
//            ChangeEntityData cedA = this.fileChangeEntityData.get(fileNameA);
//            Global.ced = cedA;
//            FileInnerLinksGenerator associationGenerator = new FileInnerLinksGenerator(cedA);
//            associationGenerator.generateFile();
//            totalFileLinks.addEntry(fileNameA, cedA.mLinks);
//        }
//        for (int i = 0; i < fileNames.size(); i++) {
//            String fileNameA = fileNames.get(i);
//            //瀛樺湪fileName涓簄ull鐨勬儏鍐碉紝澶勭悊fileName涓轰綍涓簄ull鐨勬儏鍐典箣鍚庡啀鍋氬鐞嗐��
//                ChangeEntityData cedA = this.fileChangeEntityData.get(fileNameA);
//                FileOuterLinksGenerator fileOuterLinksGenerator = new FileOuterLinksGenerator();
//                for (int j = i + 1; j < fileNames.size(); j++) {
//                    String fileNameB = fileNames.get(j);
//                    //瀛樺湪fileName涓簄ull鐨勬儏鍐�
//                        ChangeEntityData cedB = this.fileChangeEntityData.get(fileNameB);
//                        fileOuterLinksGenerator.generateOutsideAssociation(cedA, cedB);
//                        totalFileLinks.addFile2FileAssos(fileNameA, fileNameB, fileOuterLinksGenerator.mAssos);
//                }
//        }
//        new FileOuterLinksGenerator().checkSimilarity(this.fileChangeEntityData,totalFileLinks);
//        clDiffCore.mFileOutputLog.writeLinkJson(totalFileLinks.toAssoJSonString());
//        System.out.println(totalFileLinks.toConsoleString());
        fileChangeEntityData.clear();
        filePairDatas.clear();
        
    }


    public float distance(Tree tree1, Tree tree2) {
        TreeDistance treeDistance = new TreeDistance(tree1, tree2);
        float distance = treeDistance.calculateTreeDistance();
        return distance;
    }
}
