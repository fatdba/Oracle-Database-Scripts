REM ------------------------------------------------------------------------------------------------
REM $Id: plusenv.sql,v 1.4 2003/03/26 18:04:47 dixi Exp $
REM Author     : dixi
REM #DESC      : Set default sqlplus environment
REM Usage      : run automatically at sqlplus logon
REM Description: called by login.sql
REM ------------------------------------------------------------------------------------------------

set autocommit off
set echo off 
set feed on
set head on
set lines 250
set long 10000
set pages 1000 
set serveroutput on size 1000000
set trimspool on 
set verify off
set pause off
ttitle off
clear breaks
clear columns

col blksz	new_value blocksz

set termout off
select value blksz
  from v$parameter
  where name = 'db_block_size' 
;
alter session set nls_date_format = 'YYYY/MM/DD HH24:MI:SS';
set termout on 
