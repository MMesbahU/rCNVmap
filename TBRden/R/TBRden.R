#!/usr/bin/env R

#Copyright (c) 2016 Ryan Collins and Jake Conway
#Distributed under terms of the MIT License

#TBRden: master function to perform burden analyses between two sets
#of outputs from TBRden_pileup.sh (see related documentation)

TBRden <- function(controls,         #Path to TBRden_pileup.sh output for the control group
                   cases,            #Path to TBRden_pileup.sh output for the comparison group
                   QQ=T,             #Automatically generate QQ plot
                   manhattan=T,      #Automatically generate manhattan plot
                   manColor="green", #Color for manhattan plot
                   adjusted=1E-8,    #Adjusted p-value for genome-wide significance
                   return=F,         #Return results as data frame
                   OUTDIR=NULL,      #Output directory for writing results
                   prefix="TBRden",  #Prefix to be appended to results and QQ plot
                   gzip=T            #Gzip output
){
  #Sanity check input files
  if(!(file.exists(controls))){
    stop(paste("Input file ",controls," does not exist.",sep=""))
  }
  if(!(file.exists(cases))){
    stop(paste("Input file ",cases," does not exist.",sep=""))
  }

  #Import control data
  CTRL <- read.table(controls,header=T,comment.char="",sep="\t")
  names(CTRL)[1] <- "chr"

  #Import case data
  CASE <- read.table(cases,header=T,comment.char="",sep="\t")
  names(CASE)[1] <- "chr"

  #Merge cases and controls and subset to relevant columns
  ALL <- merge(CTRL,CASE,by=1:4,sort=F,suffixes=c(".CTRL",".CASE"))

  #Print warning if number of rows in merged case + control file doesn't match cases or controls
  if(nrow(CASE)!=nrow(ALL) | nrow(CTRL)!=nrow(ALL)){
    warning("TBR definitions are apparently inconsistent between cases and controls. Proceeding anyway...")
  }

  #Run Fisher test on TBR vs left and right TADs separately
  fisher.L <- t(apply(ALL[,c(5:6,8:9)],1,function(vals){
    TBR.fisher.test(vals[1],vals[2],vals[3],vals[4])
  }))
  fisher.R <- t(apply(ALL[,c(5,7:8,10)],1,function(vals){
    TBR.fisher.test(vals[1],vals[2],vals[3],vals[4])
  }))

  #Run Fisher test on TBR vs left+right TADs
  fisher.M <- t(apply(ALL[,5:10],1,function(vals){
    TBR.fisher.test(vals[1],sum(vals[2:3],na.rm=T),vals[4],sum(vals[5:6],na.rm=T))
  }))

  #Report minimum p-value for each TBR between left and right comparisons
  fisher <- as.data.frame(cbind(fisher.L,fisher.R,fisher.M))
  fisher[,7] <- apply(fisher[,c(1,3)],1,min,na.rm=T)
  names(fisher) <- c("p.Left","OR.Left","p.Right","OR.Right",
                     "p.Combined","OR.Combined","p.Min")

  #Optional: generate QQ plot
  if(QQ==T){
    pdf(paste(OUTDIR,"/",prefix,".QQ.pdf",sep=""),height=6,width=6)
    cleanQQ(fisher[,7],adjusted=adjusted)
    dev.off()
  }

  #Clean output data frame and write to file
  res <- cbind(ALL,fisher)
  write.table(res,paste(OUTDIR,"/",prefix,".TBRden_results.bed",sep=""),
              col.names=T,row.names=F,sep="\t",quote=F)
  if(gzip==T){
    system(paste("gzip -f ",OUTDIR,"/",prefix,".TBRden_results.bed",sep=""))
  }

  #Optional: generate manhattan plot
  if(manhattan==T){
    df <- res[,c(1,2,ncol(res))]
    names(df) <- c("CHR","BP","P")
    df$CHR <- as.numeric(as.character(df$CHR))
    pdf(paste(OUTDIR,"/",prefix,".manhattan.pdf",sep=""),height=4,width=8)
    cleanManhattan(df,adjusted=adjusted,theme=manColor)
    dev.off()
  }

  #Optional: return results
  if(return==T){
    return(res)
  }

}
