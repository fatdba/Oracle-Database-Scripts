-- My test script
configure backup optimization on;
configure controlfile autobackup on;
configure controlfile autobackup format for device type disk to '/archiva/backup/%F';
configure maxsetsize to unlimited;
configure device type disk parallelism 4;
run
{
allocate channel c1 type disk format '/archiva/backup/%I-%Y%M%D-%U' maxpiecesize 3G;
allocate channel c2 type disk format '/archiva/backup/%I-%Y%M%D-%U' maxpiecesize 3G;
allocate channel c3 type disk format '/archiva/backup/%I-%Y%M%D-%U' maxpiecesize 3G;
allocate channel c4 type disk format '/archiva/backup/%I-%Y%M%D-%U' maxpiecesize 3G;
backup as compressed backupset incremental level 0 check logical database plus archivelog ;
release channel c1 ;
release channel c2 ;
release channel c3 ;
release channel c4 ;
}
