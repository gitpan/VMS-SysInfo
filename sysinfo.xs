/* VMS::SysInfo - Get info for a VMS node
 *
 * Version: 0.01
 * Author:  Dan Sugalski <sugalsd@lbcc.cc.or.us>
 * Revised: 26-August-1997
 *
 *
 * Revision History:
 *
 * 0.1  26-August-1997 Dan Sugalski <sugalsd@lbcc.cc.or.us>
 *      Snagged base code from VMS::ProcInfo
 *
 */

#ifdef __cplusplus
extern "C" {
#endif
#include <starlet.h>
#include <descrip.h>
#include <syidef.h>
#include <prcdef.h>
#include <prdef.h>
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#ifdef __cplusplus
}
#endif

typedef struct {short   buflen,          /* Length of output buffer */
                        itmcode;         /* Item code */
                void    *buffer;         /* Buffer address */
                void    *retlen;         /* Return length address */
              } ITMLST;                  /* Layout of item-list elements */

typedef struct {char  *ItemName;         /* Name of the item we're getting */
                unsigned short *ReturnLength; /* Pointer to the return */
                                              /* buffer length */
                void  *ReturnBuffer;     /* generic pointer to the returned */
                                         /* data */
                int   ReturnType;        /* The type of data in the return */
                                         /* buffer */
                int   ItemListEntry;     /* Index of the entry in the item */
                                         /* list we passed to GETSYI */
              } FetchedItem; /* Use this keep track of the items in the */
                             /* 'grab everything' GETSYI call */ 
                
/* Macro to fill in an item list entry */
#define init_itemlist(ile, length, code, bufaddr, retlen_addr) \
{ \
    (ile)->buflen = (length); \
    (ile)->itmcode = (code); \
    (ile)->buffer = (bufaddr); \
    (ile)->retlen = (retlen_addr) ;}

#define bit_test(HVPointer, BitToCheck, HVEntryName, EncodedMask) \
{ \
    if ((EncodedMask) & (BitToCheck)) \
    hv_store((HVPointer), (HVEntryName), strlen((HVEntryName)), &sv_yes, 0); \
    else \
    hv_store((HVPointer), (HVEntryName), strlen((HVEntryName)), &sv_no, 0);}   

#define IS_STRING 1
#define IS_LONGWORD 2
#define IS_QUADWORD 3
#define IS_WORD 4
#define IS_BYTE 5
#define IS_VMSDATE 6
#define IS_BITMAP 7   /* Each bit in the return value indicates something */
#define IS_ENUM 8     /* Each returned value has a name, and we ought to */
                      /* return the name instead of the value */
#define IS_STRANGE 9  /* All the odd stuff (6 and 12 byte numbers, f'r ex) */
#define IS_BYTEBOOL 10 /* One-byte boolean values */

struct SysInfoID {
  char *SysInfoName; /* Pointer to the item name */
  int  SYIValue;      /* Value to use in the getsyi item list */
  int  BufferLen;     /* Length the return va buf needs to be. (no nul */
                      /* terminators, so must be careful with the return */
                      /* values. */
  int  ReturnType;    /* Type of data the item returns */
  int     LocalOnly;  /* True if the item is good only for the local node, */
                      /* false for cluster-wide items */
};

struct SysParmID {
  char *SysParmName; /* Pointer to the item name */
  int  SYIValue;      /* Value to use in the getsyi item list */
  int  BufferLen;     /* Length the return va buf needs to be. (no nul */
                      /* terminators, so must be careful with the return */
                      /* values. */
  int  ReturnType;    /* Type of data the item returns */
  int     LocalOnly;  /* True if the item is good only for the local node, */
                      /* false for cluster-wide items */
};

struct SysInfoID SysInfoList[] =
{
  {"ACTIVECPU_CNT", SYI$_ACTIVECPU_CNT, 4, IS_LONGWORD, FALSE},
  {"ACTIVE_CPU_MASK", SYI$_ACTIVE_CPU_MASK, 4, IS_LONGWORD, TRUE},
  {"ARCHFLAG", SYI$_ARCHFLAG, 4, IS_BITMAP, FALSE},
  {"ARCH_NAME", SYI$_ARCH_NAME, 15, IS_STRING, FALSE},
  {"ARCH_TYPE", SYI$_ARCH_TYPE, 4, IS_ENUM, FALSE},
  {"AVAILCPU_CNT", SYI$_AVAILCPU_CNT, 4, IS_LONGWORD, TRUE},
  {"AVAIL_CPU_MASK", SYI$_AVAIL_CPU_MASK, 4, IS_LONGWORD, TRUE},
  {"BOOTTIME", SYI$_BOOTTIME, 8, IS_VMSDATE, TRUE},
  {"CHARACTER_EMULATED", SYI$_CHARACTER_EMULATED, 1, IS_BYTEBOOL, TRUE},
  {"CLUSTER_FSYSID", SYI$_CLUSTER_FSYSID, 6, IS_STRANGE, FALSE},
  {"CLUSTER_EVOTES", SYI$_CLUSTER_EVOTES, 2, IS_WORD, FALSE},
  {"CLUSTER_FTIME", SYI$_CLUSTER_FTIME, 8, IS_VMSDATE, FALSE},
  {"CLUSTER_MEMBER", SYI$_CLUSTER_MEMBER, 1, IS_BYTEBOOL, FALSE},
  {"CLUSTER_NODES", SYI$_CLUSTER_NODES, 2, IS_WORD, FALSE},
  {"CLUSTER_QUORUM", SYI$_CLUSTER_QUORUM, 2, IS_WORD, FALSE},
  {"CLUSTER_VOTES", SYI$_CLUSTER_VOTES, 2, IS_WORD, FALSE},
  {"CONTIG_GBLPAGES", SYI$_CONTIG_GBLPAGES, 4, IS_LONGWORD, FALSE},
  {"CPU", SYI$_CPU, 4, IS_ENUM, TRUE},
  {"CPUTYPE", SYI$_CPUTYPE, 4, IS_ENUM, FALSE},
  {"DECIMAL_EMULATED", SYI$_DECIMAL_EMULATED, 1, IS_BYTEBOOL, TRUE},
  {"DECNET_FULLNAME", SYI$_DECNET_FULLNAME, 255, IS_STRING, FALSE},
  {"D_FLOAT_EMULATED", SYI$_D_FLOAT_EMULATED, 1, IS_BYTEBOOL, TRUE},
  {"DEF_PRIO_MAX", SYI$_DEF_PRIO_MAX, 4, IS_LONGWORD, FALSE},
  {"DEF_PRIO_MIN", SYI$_DEF_PRIO_MIN, 4, IS_LONGWORD, FALSE},
  {"ERLBUFFERPAGES", SYI$_ERLBUFFERPAGES, 4, IS_LONGWORD, FALSE},
  {"ERRORLOGBUFFERS", SYI$_ERRORLOGBUFFERS, 2, IS_WORD, FALSE},
  {"F_FLOAT_EMULATED", SYI$_F_FLOAT_EMULATED, 1, IS_BYTEBOOL, TRUE},
  {"FREE_GBLPAGES", SYI$_FREE_GBLPAGES, 4, IS_LONGWORD, FALSE},
  {"FREE_GBLSECTS", SYI$_FREE_GBLSECTS, 4, IS_LONGWORD, FALSE},
  {"G_FLOAT_EMULATED", SYI$_G_FLOAT_EMULATED, 1, IS_BYTEBOOL, TRUE},
  {"GH_RSRVPGCNT", SYI$_GH_RSRVPGCNT, 4, IS_LONGWORD, FALSE},
  {"H_FLOAT_EMULATED", SYI$_H_FLOAT_EMULATED, 1, IS_BYTEBOOL, TRUE},
  {"HW_MODEL", SYI$_HW_MODEL, 2, IS_WORD, FALSE},
  {"HW_NAME", SYI$_HW_NAME, 31, IS_STRING, FALSE},
  {"ITB_ENTRIES", SYI$_ITB_ENTRIES, 4, IS_LONGWORD, FALSE},
  {"MAX_CPUS", SYI$_MAX_CPUS, 4, IS_LONGWORD, TRUE},
  {"MAX_PFN", SYI$_MAX_PFN, 4, IS_LONGWORD, FALSE},
  {"MEMSIZE", SYI$_MEMSIZE, 4, IS_LONGWORD, FALSE},
  {"NODE_AREA", SYI$_NODE_AREA, 4, IS_LONGWORD, FALSE},
  {"NODE_CSID", SYI$_NODE_CSID, 4, IS_LONGWORD, FALSE},
  {"NODE_EVOTES", SYI$_NODE_EVOTES, 2, IS_WORD, FALSE},
  {"NODE_HWVERS", SYI$_NODE_HWVERS, 12, IS_STRANGE, FALSE},
  {"NODE_NUMBER", SYI$_NODE_NUMBER, 4, IS_LONGWORD, FALSE},
  {"NODE_QUORUM", SYI$_NODE_QUORUM, 2, IS_WORD, FALSE},
  {"NODE_SWINCARN", SYI$_NODE_SWINCARN, 8, IS_QUADWORD, FALSE},
  {"NODE_SWTYPE", SYI$_NODE_SWTYPE, 4, IS_STRING, FALSE},
  {"NODE_SWVERS", SYI$_NODE_SWVERS, 4, IS_STRING, FALSE},
  {"NODE_SYSTEMID", SYI$_NODE_SYSTEMID, 6, IS_STRANGE, FALSE},
  {"NODE_VOTES", SYI$_NODE_VOTES, 2, IS_WORD, FALSE},
  {"NODENAME", SYI$_NODENAME, 15, IS_STRING, FALSE},
  {"PAGEFILE_FREE", SYI$_PAGEFILE_FREE, 4, IS_LONGWORD, TRUE},
  {"PAGEFILE_PAGE", SYI$_PAGEFILE_PAGE, 4, IS_LONGWORD, TRUE},
  {"PAGE_SIZE", SYI$_PAGE_SIZE, 4, IS_LONGWORD, FALSE},
  {"PHYSICALPAGES", SYI$_PHYSICALPAGES, 4, IS_LONGWORD, FALSE},
  {"PMD_COUNT", SYI$_PMD_COUNT, 4, IS_LONGWORD, FALSE},
  {"PRIMARY_CPUID", SYI$_PRIMARY_CPUID, 4, IS_LONGWORD, TRUE},
  {"PROCESS_SPACE_LIMIT", SYI$_PROCESS_SPACE_LIMIT, 8, IS_QUADWORD, FALSE},
  {"PSXFIFO_PRIO_MAX", SYI$_PSXFIFO_PRIO_MAX, 4, IS_LONGWORD, FALSE},
  {"PSXFIFO_PRIO_MIN", SYI$_PSXFIFO_PRIO_MIN, 4, IS_LONGWORD, FALSE},
  {"PSXRR_PRIO_MAX", SYI$_PSXRR_PRIO_MAX, 4, IS_LONGWORD, FALSE},
  {"PSXRR_PRIO_MIN", SYI$_PSXRR_PRIO_MIN, 4, IS_LONGWORD, FALSE},
  {"PT_BASE", SYI$_PT_BASE, 8, IS_QUADWORD, FALSE},
  {"PTES_PER_PAGE", SYI$_PTES_PER_PAGE, 4, IS_LONGWORD, TRUE},
  {"REAL_CPUTYPE", SYI$_REAL_CPUTYPE, 4, IS_ENUM, FALSE},
  {"SCS_EXISTS", SYI$_SCS_EXISTS, 4, IS_LONGWORD, FALSE},
  {"SHARED_VA_PTES", SYI$_SHARED_VA_PTES, 8, IS_QUADWORD, FALSE},
  {"SID", SYI$_SID, 4, IS_LONGWORD, FALSE},
  {"SWAPFILE_FREE", SYI$_SWAPFILE_FREE, 4, IS_LONGWORD, TRUE},
  {"SWAPFILE_PAGE", SYI$_SWAPFILE_PAGE, 4, IS_LONGWORD, TRUE},
#ifdef SYI$_SYSTYPE
  {"SYSTYPE", SYI$_SYSTYPE, 4, IS_ENUM, FALSE},
#endif
  {"VERSION", SYI$_VERSION, 8, IS_STRING, TRUE},
  {"VECTOR_EMULATOR", SYI$_VECTOR_EMULATOR, 1, IS_BYTEBOOL, FALSE},
  {"VP_MASK", SYI$_VP_MASK, 4, IS_LONGWORD, FALSE},
  {"VP_NUMBER", SYI$_VP_NUMBER, 4, IS_LONGWORD, FALSE},
  {"XCPU", SYI$_XCPU, 4, IS_LONGWORD, TRUE},
  {"XSID", SYI$_XSID, 4, IS_LONGWORD, TRUE},
  {NULL, 0, 0, 0, 0}
};

/* This array has the same structure as the SysInfoList array, even though */
/* the local flag isn't ever used. Easier this way. */
struct SysParmID SysParmList[] =
{
  {"ACP_BASEPRIO", SYI$_ACP_BASEPRIO, 4, IS_LONGWORD, TRUE},
  {"ACP_DATACHECK", SYI$_ACP_DATACHECK, 4, IS_LONGWORD, TRUE},
  {"ACP_DINDXCACHE", SYI$_ACP_DINDXCACHE, 4, IS_LONGWORD, TRUE},
  {"ACP_DIRCACHE", SYI$_ACP_DIRCACHE, 4, IS_LONGWORD, TRUE},
  {"ACP_EXTCACHE", SYI$_ACP_EXTCACHE, 4, IS_LONGWORD, TRUE},
  {"ACP_EXTLIMIT", SYI$_ACP_EXTLIMIT, 4, IS_LONGWORD, TRUE},
  {"ACP_FIDCACHE", SYI$_ACP_FIDCACHE, 4, IS_LONGWORD, TRUE},
  {"ACP_HDRCACHE", SYI$_ACP_HDRCACHE, 4, IS_LONGWORD, TRUE},
  {"ACP_MAPCACHE", SYI$_ACP_MAPCACHE, 4, IS_LONGWORD, TRUE},
  {"ACP_MAXREAD", SYI$_ACP_MAXREAD, 4, IS_LONGWORD, TRUE},
  {"ACP_MULTIPLE", SYI$_ACP_MULTIPLE, 4, IS_LONGWORD, TRUE},
  {"ACP_QUOCACHE", SYI$_ACP_QUOCACHE, 4, IS_LONGWORD, TRUE},
  {"ACP_REBLDSYSD", SYI$_ACP_REBLDSYSD, 4, IS_LONGWORD, TRUE},
  {"ACP_SHARE", SYI$_ACP_SHARE, 4, IS_LONGWORD, TRUE},
  {"ACP_SWAPFLGS", SYI$_ACP_SWAPFLGS, 4, IS_LONGWORD, TRUE},
  {"ACP_SYSACC", SYI$_ACP_SYSACC, 4, IS_LONGWORD, TRUE},
  {"ACP_WINDOW", SYI$_ACP_WINDOW, 4, IS_LONGWORD, TRUE},
  {"ACP_WORKSET", SYI$_ACP_WORKSET, 4, IS_LONGWORD, TRUE},
  {"ACP_WRITEBACK", SYI$_ACP_WRITEBACK, 4, IS_LONGWORD, TRUE},
  {"ACP_XQP_RES", SYI$_ACP_XQP_RES, 4, IS_LONGWORD, TRUE},
  {"ALLOCLASS", SYI$_ALLOCLASS, 4, IS_LONGWORD, TRUE},
  {"AVAIL_PAGES", SYI$_AVAIL_PAGES, 4, IS_LONGWORD, TRUE},
  {"AWSMIN", SYI$_AWSMIN, 4, IS_LONGWORD, TRUE},
  {"AWSTIME", SYI$_AWSTIME, 4, IS_LONGWORD, TRUE},
  {"BALSETCNT", SYI$_BALSETCNT, 4, IS_LONGWORD, TRUE},
  {"BAL_SLOTS", SYI$_BAL_SLOTS, 4, IS_LONGWORD, TRUE},
  {"BORROWLIM", SYI$_BORROWLIM, 4, IS_LONGWORD, TRUE},
  {"CHANNELCNT", SYI$_CHANNELCNT, 4, IS_LONGWORD, TRUE},
  {"CLOCK_INTERVAL", SYI$_CLOCK_INTERVAL, 4, IS_LONGWORD, TRUE},
  {"CLUSTER_CREDITS", SYI$_CLUSTER_CREDITS, 4, IS_LONGWORD, TRUE},
  {"CONSOLE_VERSION", SYI$_CONSOLE_VERSION, 20, IS_STRING, TRUE},
  {"CTLIMGLIM", SYI$_CTLIMGLIM, 4, IS_LONGWORD, TRUE},
  {"CTLPAGES", SYI$_CTLPAGES, 4, IS_LONGWORD, TRUE},
  {"DLCKEXTRASTK", SYI$_DLCKEXTRASTK, 4, IS_LONGWORD, TRUE},
  {"EXPECTED_VOTES", SYI$_EXPECTED_VOTES, 4, IS_LONGWORD, TRUE},
  {"FAST_PATH", SYI$_FAST_PATH, 4, IS_LONGWORD, TRUE},
  {"FREEGOAL", SYI$_FREEGOAL, 4, IS_LONGWORD, TRUE},
  {"FREELIM", SYI$_FREELIM, 4, IS_LONGWORD, TRUE},
  {"GBLPAGES", SYI$_GBLPAGES, 4, IS_LONGWORD, TRUE},
  {"GBLPAGFIL", SYI$_GBLPAGFIL, 4, IS_LONGWORD, TRUE},
  {"GBLSECTIONS", SYI$_GBLSECTIONS, 4, IS_LONGWORD, TRUE},
  {"GROWLIM", SYI$_GROWLIM, 4, IS_LONGWORD, TRUE},
  {"IMGIOCNT", SYI$_IMGIOCNT, 4, IS_LONGWORD, TRUE},
  {"INTSTKPAGES", SYI$_INTSTKPAGES, 4, IS_LONGWORD, TRUE},
  {"IOTA", SYI$_IOTA, 4, IS_LONGWORD, TRUE},
  {"IRPCOUNT", SYI$_IRPCOUNT, 4, IS_LONGWORD, TRUE},
  {"IRPCOUNTV", SYI$_IRPCOUNTV, 4, IS_LONGWORD, TRUE},
  {"KSTACKPAGES", SYI$_KSTACKPAGES, 4, IS_LONGWORD, TRUE},
  {"MAIN_MEMORY", SYI$_MAIN_MEMORY, 4, IS_LONGWORD, TRUE},
  {"MAXBOBMEM", SYI$_MAXBOBMEM, 4, IS_LONGWORD, TRUE},
  {"MAXBUF", SYI$_MAXBUF, 4, IS_LONGWORD, TRUE},
  {"MAXPROCESSCNT", SYI$_MAXPROCESSCNT, 4, IS_LONGWORD, TRUE},
  {"MINWSCNT", SYI$_MINWSCNT, 4, IS_LONGWORD, TRUE},
  {"MPW_HILIMIT", SYI$_MPW_HILIMIT, 4, IS_LONGWORD, TRUE},
  {"MPW_LOLIMIT", SYI$_MPW_LOLIMIT, 4, IS_LONGWORD, TRUE},
  {"NPAGEDYN", SYI$_NPAGEDYN, 4, IS_LONGWORD, TRUE},
  {"NPAGED_POOL", SYI$_PAGED_POOL, 4, IS_LONGWORD, TRUE},
  {"NPAGEVIR", SYI$_NPAGEVIR, 4, IS_LONGWORD, TRUE},
  {"PAGEDYN", SYI$_PAGEDYN, 4, IS_LONGWORD, TRUE},
  {"PAGED_POOL", SYI$_PAGED_POOL, 4, IS_LONGWORD, TRUE},
  {"PAGFILCNT", SYI$_PAGFILCNT, 4, IS_LONGWORD, TRUE},
  {"PAGTBLPFC", SYI$_PAGTBLPFC, 4, IS_LONGWORD, TRUE},
  {"PALCODE_VERSION", SYI$_PALCODE_VERSION, 20, IS_STRING, TRUE},
  {"PFCDEFAULT", SYI$_PFCDEFAULT, 4, IS_LONGWORD, TRUE},
  {"PFRATH", SYI$_PFRATH, 4, IS_LONGWORD, TRUE},
  {"PFRATL", SYI$_PFRATL, 4, IS_LONGWORD, TRUE},
  {"PFRATL_SYS", SYI$_PFRATL_SYS, 4, IS_LONGWORD, TRUE},
#ifdef __VAX
  {"PHYSICAL_MEMORY", SYI$_PHYSICAL_MEMORY, 4, IS_LONGWORD, TRUE},
#else
  {"PHYSICAL_MEMORY", SYI$_PHYSICAL_MEMORY, 8, IS_QUADWORD, TRUE},
#endif
  {"PIOPAGES", SYI$_PIOPAGES, 4, IS_LONGWORD, TRUE},
  {"PIXSCAN", SYI$_PIXSCAN, 4, IS_LONGWORD, TRUE},
  {"PROCSECTCNT", SYI$_PROCSECTCNT, 4, IS_LONGWORD, TRUE},
  {"PROC_SLOTS", SYI$_PROC_SLOTS, 4, IS_LONGWORD, TRUE},
  {"QUANTUM", SYI$_QUANTUM, 4, IS_LONGWORD, TRUE},
  {"S2_SIZE", SYI$_S2_SIZE, 4, IS_LONGWORD, TRUE},
  {"SCSNODE", SYI$_SCSNODE, 255, IS_STRING, TRUE},
  {"STARTUP_P1", SYI$_STARTUP_P1, 255, IS_STRING, TRUE},
  {"STARTUP_P2", SYI$_STARTUP_P2, 255, IS_STRING, TRUE},
  {"STARTUP_P3", SYI$_STARTUP_P3, 255, IS_STRING, TRUE},
  {"STARTUP_P4", SYI$_STARTUP_P4, 255, IS_STRING, TRUE},
  {"STARTUP_P5", SYI$_STARTUP_P5, 255, IS_STRING, TRUE},
  {"SWPFILCNT", SYI$_SWPFILCNT, 4, IS_LONGWORD, TRUE},
  {"SYSMWCNT", SYI$_SYSMWCNT, 4, IS_LONGWORD, TRUE},
  {"SYSPFC", SYI$_SYSPFC, 4, IS_LONGWORD, TRUE},
  {"USED_GBLPAGCNT", SYI$_USED_GBLPAGCNT, 4, IS_LONGWORD, TRUE},
  {"USED_GBLPAGMAX", SYI$_USED_GBLPAGMAX, 4, IS_LONGWORD, TRUE},
  {"USED_GBLSECTCNT", SYI$_USED_GBLSECTCNT, 4, IS_LONGWORD, TRUE},
  {"USED_GBLSECTMAX", SYI$_USED_GBLSECTMAX, 4, IS_LONGWORD, TRUE},
#ifdef __VAX
  {"VIRTUALPAGECNT", SYI$_VIRTUALPAGECNT, 4, IS_LONGWORD, TRUE},
#else
  {"VIRTUALPAGECNT", SYI$_VIRTUALPAGECNT, 8, IS_QUADWORD, TRUE},
#endif
  {"WINDOW_SYSTEM", SYI$_WINDOW_SYSTEM, 64, IS_STRING, TRUE},
  {"WSDEC", SYI$_WSDEC, 4, IS_LONGWORD, TRUE},
  {"WSINC", SYI$_WSINC, 4, IS_LONGWORD, TRUE},
  {"WSMAX", SYI$_WSMAX, 4, IS_LONGWORD, TRUE},
  {"BUGCHECKFATAL", SYI$_BUGCHECKFATAL, 4, IS_LONGWORD, TRUE},
  {"BUGREBOOT", SYI$_BUGREBOOT, 4, IS_LONGWORD, TRUE},
#ifdef SYI$_CHECK_CLUSTER
  {"CHECK_CLUSTER", SYI$_CHECK_CLUSTER, 4, IS_LONGWORD, TRUE},
#endif
  {"CLASS_PROT", SYI$_CLASS_PROT, 4, IS_LONGWORD, TRUE},
  {"CLISYMTBL", SYI$_CLISYMTBL, 4, IS_LONGWORD, TRUE},
  {"CRDENABLE", SYI$_CRDENABLE, 4, IS_LONGWORD, TRUE},
  {"CWCREPRC_ENABLE", SYI$_CWCREPRC_ENABLE, 4, IS_LONGWORD, TRUE},
  {"DBGTK_SCRATCH", SYI$_DBGTK_SCRATCH, 4, IS_LONGWORD, TRUE},
  {"DEADLOCK_WAIT", SYI$_DEADLOCK_WAIT, 4, IS_LONGWORD, TRUE},
  {"DEFMBXBUFQUO", SYI$_DEFMBXBUFQUO, 4, IS_LONGWORD, TRUE},
  {"DEFMBXMXMSG", SYI$_DEFMBXMXMSG, 4, IS_LONGWORD, TRUE},
  {"DEFPRI", SYI$_DEFPRI, 4, IS_LONGWORD, TRUE},
  {"DEFQUEPRI", SYI$_DEFQUEPRI, 4, IS_LONGWORD, TRUE},
  {"DEVICE_NAMING", SYI$_DEVICE_NAMING, 4, IS_LONGWORD, TRUE},
  {"DISK_QUORUM", SYI$_DISK_QUORUM, 4, IS_LONGWORD, TRUE},
  {"DORMANTWAIT", SYI$_DORMANTWAIT, 4, IS_LONGWORD, TRUE},
  {"DR_UNIT_BASE", SYI$_DR_UNIT_BASE, 4, IS_LONGWORD, TRUE},
  {"DUMPBUG", SYI$_DUMPBUG, 4, IS_LONGWORD, TRUE},
  {"DUMPSTYLE", SYI$_DUMPSTYLE, 4, IS_LONGWORD, TRUE},
  {"ERLBUFFERPAGES", SYI$_ERLBUFFERPAGES, 4, IS_LONGWORD, TRUE},
  {"ERRORLOGBUFFERS", SYI$_ERRORLOGBUFFERS, 4, IS_LONGWORD, TRUE},
  {"GH_EXEC_CODE", SYI$_GH_EXEC_CODE, 4, IS_LONGWORD, TRUE},
  {"GH_EXEC_DATA", SYI$_GH_EXEC_DATA, 4, IS_LONGWORD, TRUE},
  {"GH_RES_CODE", SYI$_GH_RES_CODE, 4, IS_LONGWORD, TRUE},
  {"GH_RES_DATA", SYI$_GH_RES_DATA, 4, IS_LONGWORD, TRUE},
  {"GH_RSRVPGCNT", SYI$_GH_RSRVPGCNT, 4, IS_LONGWORD, TRUE},
  {"GROWLIM", SYI$_GROWLIM, 4, IS_LONGWORD, TRUE},
  {"IEEE_ADDRESS", SYI$_IEEE_ADDRESS, 4, IS_LONGWORD, TRUE},
  {"IEEE_ADDRESSH", SYI$_IEEE_ADDRESSH, 4, IS_LONGWORD, TRUE},
  {"IJOBLIM", SYI$_IJOBLIM, 4, IS_LONGWORD, TRUE},
  {"IMGREG_PAGES", SYI$_IMGREG_PAGES, 4, IS_LONGWORD, TRUE},
  {"IO_PREFER_CPUS", SYI$_IO_PREFER_CPUS, 4, IS_LONGWORD, TRUE},
  {"LAMAPREGS", SYI$_LAMAPREGS, 4, IS_LONGWORD, TRUE},
  {"LAN_FLAGS", SYI$_LAN_FLAGS, 4, IS_LONGWORD, TRUE},
  {"LGI_BRK_DISUSER", SYI$_LGI_BRK_DISUSER, 4, IS_LONGWORD, TRUE},
  {"LGI_BRK_LIM", SYI$_LGI_BRK_LIM, 4, IS_LONGWORD, TRUE},
  {"LGI_BRK_TERM", SYI$_LGI_BRK_TERM, 4, IS_LONGWORD, TRUE},
  {"LGI_BRK_TMO", SYI$_LGI_BRK_TMO, 4, IS_LONGWORD, TRUE},
  {"LGI_CALLOUTS", SYI$_LGI_CALLOUTS, 4, IS_LONGWORD, TRUE},
  {"LGI_HID_TIM", SYI$_LGI_HID_TIM, 4, IS_LONGWORD, TRUE},
  {"LGI_PWD_TMO", SYI$_LGI_PWD_TMO, 4, IS_LONGWORD, TRUE},
  {"LGI_RETRY_LIM", SYI$_LGI_RETRY_LIM, 4, IS_LONGWORD, TRUE},
  {"LGI_RETRY_TMO", SYI$_LGI_RETRY_TMO, 4, IS_LONGWORD, TRUE},
  {"LNMPHASHTBL", SYI$_LNMPHASHTBL, 4, IS_LONGWORD, TRUE},
  {"LNMSHASHTBL", SYI$_LNMSHASHTBL, 4, IS_LONGWORD, TRUE},
  {"LOAD_PWD_POLICY", SYI$_LOAD_PWD_POLICY, 4, IS_LONGWORD, TRUE},
  {"LOCKDIRWT", SYI$_LOCKDIRWT, 4, IS_LONGWORD, TRUE},
  {"LOCKIDTBL", SYI$_LOCKIDTBL, 4, IS_LONGWORD, TRUE},
  {"LONGWAIT", SYI$_LONGWAIT, 4, IS_LONGWORD, TRUE},
  {"MAXQUEPRI", SYI$_MAXQUEPRI, 4, IS_LONGWORD, TRUE},
  {"MAXSYSGROUP", SYI$_MAXSYSGROUP, 4, IS_LONGWORD, TRUE},
  {"MC_SERVICES_P0", SYI$_MC_SERVICES_P0, 4, IS_LONGWORD, TRUE},
  {"MC_SERVICES_P1", SYI$_MC_SERVICES_P1, 4, IS_LONGWORD, TRUE},
  {"MC_SERVICES_P2", SYI$_MC_SERVICES_P2, 4, IS_LONGWORD, TRUE},
  {"MC_SERVICES_P3", SYI$_MC_SERVICES_P3, 4, IS_LONGWORD, TRUE},
  {"MC_SERVICES_P4", SYI$_MC_SERVICES_P4, 4, IS_LONGWORD, TRUE},
  {"MC_SERVICES_P5", SYI$_MC_SERVICES_P5, 4, IS_LONGWORD, TRUE},
  {"MC_SERVICES_P6", SYI$_MC_SERVICES_P6, 4, IS_LONGWORD, TRUE},
  {"MC_SERVICES_P7", SYI$_MC_SERVICES_P7, 4, IS_LONGWORD, TRUE},
  {"MC_SERVICES_P8", SYI$_MC_SERVICES_P8, 4, IS_LONGWORD, TRUE},
  {"MC_SERVICES_P9", SYI$_MC_SERVICES_P9, 4, IS_LONGWORD, TRUE},
  {"MMG_CTLFLAGS", SYI$_MMG_CTLFLAGS, 4, IS_LONGWORD, TRUE},
  {"MPW_IOLIMIT", SYI$_MPW_IOLIMIT, 4, IS_LONGWORD, TRUE},
  {"MPW_LOWAITLIMIT", SYI$_MPW_LOWAITLIMIT, 4, IS_LONGWORD, TRUE},
  {"MPW_THRESH", SYI$_MPW_THRESH, 4, IS_LONGWORD, TRUE},
  {"MPW_WAITLIMIT", SYI$_MPW_WAITLIMIT, 4, IS_LONGWORD, TRUE},
  {"MPW_WRTCLUSTER", SYI$_MPW_WRTCLUSTER, 4, IS_LONGWORD, TRUE},
  {"MSCP_BUFFER", SYI$_MSCP_BUFFER, 4, IS_LONGWORD, TRUE},
  {"MSCP_CMD_TMO", SYI$_MSCP_CMD_TMO, 4, IS_LONGWORD, TRUE},
  {"MSCP_CREDITS", SYI$_MSCP_CREDITS, 4, IS_LONGWORD, TRUE},
  {"MSCP_LOAD", SYI$_MSCP_LOAD, 4, IS_LONGWORD, TRUE},
  {"MSCP_SERVE_ALL", SYI$_MSCP_SERVE_ALL, 4, IS_LONGWORD, TRUE},
  {"MULTIPROCESSING", SYI$_MULTIPROCESSING, 4, IS_LONGWORD, TRUE},
  {"MULTITHREAD", SYI$_MULTITHREAD, 4, IS_LONGWORD, TRUE},
  {"MVTIMEOUT", SYI$_MVTIMEOUT, 4, IS_LONGWORD, TRUE},
  {"NET_CALLOUTS", SYI$_NET_CALLOUTS, 4, IS_LONGWORD, TRUE},
  {"NISCS_CONV_BOOT", SYI$_NISCS_CONV_BOOT, 4, IS_LONGWORD, TRUE},
  {"NISCS_LAN_OVRHD", SYI$_NISCS_LAN_OVRHD, 4, IS_LONGWORD, TRUE},
  {"NISCS_LOAD_PEA0", SYI$_NISCS_LOAD_PEA0, 4, IS_LONGWORD, TRUE},
  {"NISCS_MAX_PKTSZ", SYI$_NISCS_MAX_PKTSZ, 4, IS_LONGWORD, TRUE},
  {"NISCS_PORT_SERV", SYI$_NISCS_PORT_SERV, 4, IS_LONGWORD, TRUE},
  {"NJOBLIM", SYI$_NJOBLIM, 4, IS_LONGWORD, TRUE},
  {"NPAG_AGGRESSIVE", SYI$_NPAG_AGGRESSIVE, 4, IS_LONGWORD, TRUE},
  {"NPAG_BAP_MAX", SYI$_NPAG_BAP_MAX, 4, IS_LONGWORD, TRUE},
  {"NPAG_BAP_MAX_PA", SYI$_NPAG_BAP_MAX_PA, 4, IS_LONGWORD, TRUE},
  {"NPAG_BAP_MIN", SYI$_NPAG_BAP_MIN, 4, IS_LONGWORD, TRUE},
  {"NPAG_GENTLE", SYI$_NPAG_GENTLE, 4, IS_LONGWORD, TRUE},
  {"NPAG_INTERVAL", SYI$_NPAG_INTERVAL, 4, IS_LONGWORD, TRUE},
  {"NPAG_RING_SIZE", SYI$_NPAG_RING_SIZE, 4, IS_LONGWORD, TRUE},
  {"PAMAXPORT", SYI$_PAMAXPORT, 4, IS_LONGWORD, TRUE},
  {"PANOPOLL", SYI$_PANOPOLL, 4, IS_LONGWORD, TRUE},
  {"PANUMPOLL", SYI$_PANUMPOLL, 4, IS_LONGWORD, TRUE},
  {"PAPOLLINTERVAL", SYI$_PAPOLLINTERVAL, 4, IS_LONGWORD, TRUE},
  {"PAPOOLINTERVAL", SYI$_PAPOOLINTERVAL, 4, IS_LONGWORD, TRUE},
  {"PASANITY", SYI$_PASANITY, 4, IS_LONGWORD, TRUE},
  {"PASTDGBUF", SYI$_PASTDGBUF, 4, IS_LONGWORD, TRUE},
  {"PASTIMOUT", SYI$_PASTIMOUT, 4, IS_LONGWORD, TRUE},
  {"PFCDEFAULT", SYI$_PFCDEFAULT, 4, IS_LONGWORD, TRUE},
  {"PQL_DASTLM", SYI$_PQL_DASTLM, 4, IS_LONGWORD, TRUE},
  {"PQL_DBIOLM", SYI$_PQL_DBIOLM, 4, IS_LONGWORD, TRUE},
  {"PQL_DBTYLM", SYI$_PQL_DBYTLM, 4, IS_LONGWORD, TRUE},
  {"PQL_DCPULM", SYI$_PQL_DCPULM, 4, IS_LONGWORD, TRUE},
  {"PQL_DDIOLM", SYI$_PQL_DDIOLM, 4, IS_LONGWORD, TRUE},
  {"PQL_DENQLM", SYI$_PQL_DENQLM, 4, IS_LONGWORD, TRUE},
  {"PQL_DFILLM", SYI$_PQL_DFILLM, 4, IS_LONGWORD, TRUE},
  {"PQL_DJTQUOTA", SYI$_PQL_DJTQUOTA, 4, IS_LONGWORD, TRUE},
  {"PQL_DPGFLQUOTA", SYI$_PQL_DPGFLQUOTA, 4, IS_LONGWORD, TRUE},
  {"PQL_DPRCLM", SYI$_PQL_DPRCLM, 4, IS_LONGWORD, TRUE},
  {"PQL_DTQELM", SYI$_PQL_DTQELM, 4, IS_LONGWORD, TRUE},
  {"PQL_DWSDEFAULT", SYI$_PQL_DWSDEFAULT, 4, IS_LONGWORD, TRUE},
  {"PQL_DWSEXTENT", SYI$_PQL_DWSEXTENT, 4, IS_LONGWORD, TRUE},
  {"PQL_DWSQUOTA", SYI$_PQL_DWSQUOTA, 4, IS_LONGWORD, TRUE},
  {"PQL_MASTLM", SYI$_PQL_MASTLM, 4, IS_LONGWORD, TRUE},
  {"PQL_MBIOLM", SYI$_PQL_MBIOLM, 4, IS_LONGWORD, TRUE},
  {"PQL_MBTYLM", SYI$_PQL_MBYTLM, 4, IS_LONGWORD, TRUE},
  {"PQL_MCPULM", SYI$_PQL_MCPULM, 4, IS_LONGWORD, TRUE},
  {"PQL_MDIOLM", SYI$_PQL_MDIOLM, 4, IS_LONGWORD, TRUE},
  {"PQL_MENQLM", SYI$_PQL_MENQLM, 4, IS_LONGWORD, TRUE},
  {"PQL_MFILLM", SYI$_PQL_MFILLM, 4, IS_LONGWORD, TRUE},
  {"PQL_MJTQUOTA", SYI$_PQL_MJTQUOTA, 4, IS_LONGWORD, TRUE},
  {"PQL_MPGFLQUOTA", SYI$_PQL_MPGFLQUOTA, 4, IS_LONGWORD, TRUE},
  {"PQL_MPRCLM", SYI$_PQL_MPRCLM, 4, IS_LONGWORD, TRUE},
  {"PQL_MTQELM", SYI$_PQL_MTQELM, 4, IS_LONGWORD, TRUE},
  {"PQL_MWSDEFAULT", SYI$_PQL_MWSDEFAULT, 4, IS_LONGWORD, TRUE},
  {"PQL_MWSEXTENT", SYI$_PQL_MWSEXTENT, 4, IS_LONGWORD, TRUE},
  {"PQL_MWSQUOTA", SYI$_PQL_MWSQUOTA, 4, IS_LONGWORD, TRUE},
  {"PRCPOLINTERVAL", SYI$_PRCPOLINTERVAL, 4, IS_LONGWORD, TRUE},
  {"QDSKINTERVAL", SYI$_QDSKINTERVAL, 4, IS_LONGWORD, TRUE},
  {"QDSKVOTES", SYI$_QDSKVOTES, 4, IS_LONGWORD, TRUE},
  {"REALTIME_SPTS", SYI$_REALTIME_SPTS, 4, IS_LONGWORD, TRUE},
  {"RECNXINTERVAL", SYI$_RECNXINTERVAL, 4, IS_LONGWORD, TRUE},
  {"RESHASHTBL", SYI$_RESHASHTBL, 4, IS_LONGWORD, TRUE},
  {"RJOBLIM", SYI$_RJOBLIM, 4, IS_LONGWORD, TRUE},
  {"RMS_DFMBC", SYI$_RMS_DFMBC, 4, IS_LONGWORD, TRUE},
  {"RMS_DFMBFIDX", SYI$_RMS_DFMBFIDX, 4, IS_LONGWORD, TRUE},
  {"RMS_DFMBFREL", SYI$_RMS_DFMBFREL, 4, IS_LONGWORD, TRUE},
  {"RMS_DFMBFSDK", SYI$_RMS_DFMBFSDK, 4, IS_LONGWORD, TRUE},
  {"RMS_DFMBFSMT", SYI$_RMS_DFMBFSMT, 4, IS_LONGWORD, TRUE},
  {"RMS_DFMBFSUR", SYI$_RMS_DFMBFSUR, 4, IS_LONGWORD, TRUE},
  {"RMS_DFNBC", SYI$_RMS_DFNBC, 4, IS_LONGWORD, TRUE},
  {"RMS_EXTEND_SIZE", SYI$_RMS_EXTEND_SIZE, 4, IS_LONGWORD, TRUE},
  {"RMS_FILEPROT", SYI$_RMS_FILEPROT, 4, IS_LONGWORD, TRUE},
  {"RMS_PROLOGUE", SYI$_RMS_PROLOGUE, 4, IS_LONGWORD, TRUE},
  {"SAVEDUMP", SYI$_SAVEDUMP, 4, IS_LONGWORD, TRUE},
  {"SCSBUFFCNT", SYI$_SCSBUFFCNT, 4, IS_LONGWORD, TRUE},
  {"SCSCONNCNT", SYI$_SCSCONNCNT, 4, IS_LONGWORD, TRUE},
  {"SCSFLOWCUSH", SYI$_SCSFLOWCUSH, 4, IS_LONGWORD, TRUE},
  {"SCSMAXDG", SYI$_SCSMAXDG, 4, IS_LONGWORD, TRUE},
  {"SCSMAXMSG", SYI$_SCSMAXMSG, 4, IS_LONGWORD, TRUE},
  {"SCSRESPCNT", SYI$_SCSRESPCNT, 4, IS_LONGWORD, TRUE},
  {"SCSSYSTEMID", SYI$_SCSSYSTEMID, 4, IS_LONGWORD, TRUE},
  {"SCSSYSTEMIDH", SYI$_SCSSYSTEMIDH, 4, IS_LONGWORD, TRUE},
  {"SECURITY_POLICY", SYI$_SECURITY_POLICY, 4, IS_LONGWORD, TRUE},
  {"SETTIME", SYI$_SETTIME, 4, IS_LONGWORD, TRUE},
  {"SHADOWING", SYI$_SHADOWING, 4, IS_LONGWORD, TRUE},
  {"SHADOW_MAX_COPY", SYI$_SHADOW_MAX_COPY, 4, IS_LONGWORD, TRUE},
  {"SHADOW_MBR_TMO", SYI$_SHADOW_MBR_TMO, 4, IS_LONGWORD, TRUE},
  {"SHADOW_REMOVE_1", SYI$_SHADOW_REMOVE_1, 4, IS_LONGWORD, TRUE},
  {"SHADOW_REMOVE_2", SYI$_SHADOW_REMOVE_2, 4, IS_LONGWORD, TRUE},
  {"SHADOW_SYS_DISK", SYI$_SHADOW_SYS_DISK, 4, IS_LONGWORD, TRUE},
  {"SHADOS_SYS_TMO", SYI$_SHADOW_SYS_TMO, 4, IS_LONGWORD, TRUE},
  {"SHADOS_SYS_UNIT", SYI$_SHADOW_SYS_UNIT, 4, IS_LONGWORD, TRUE},
  {"SHADOS_SYS_WAIT", SYI$_SHADOW_SYS_WAIT, 4, IS_LONGWORD, TRUE},
  {"SMP_CPUS", SYI$_SMP_CPUS, 4, IS_LONGWORD, TRUE},
  {"SMP_LNGSPINWAIT", SYI$_SMP_LNGSPINWAIT, 4, IS_LONGWORD, TRUE},
  {"SMP_SANITY_CNT", SYI$_SMP_SANITY_CNT, 4, IS_LONGWORD, TRUE},
  {"SMP_SPINWAIT", SYI$_SMP_SPINWAIT, 4, IS_LONGWORD, TRUE},
  {"SPTREQ", SYI$_SPTREQ, 4, IS_LONGWORD, TRUE},
  {"SWPOUTPGCNT", SYI$_SWPOUTPGCNT, 4, IS_LONGWORD, TRUE},
  {"SYSTEM_CHECK", SYI$_SYSTEM_CHECK, 4, IS_LONGWORD, TRUE},
  {"TAILORED", SYI$_TAILORED, 4, IS_LONGWORD, TRUE},
  {"TAPE_ALLOCLASS", SYI$_TAPE_ALLOCLASS, 4, IS_LONGWORD, TRUE},
  {"TAPE_MVTIMEOUT", SYI$_TAPE_MVTIMEOUT, 4, IS_LONGWORD, TRUE},
  {"TIMEPROMPTWAIT", SYI$_TIMEPROMPTWAIT, 4, IS_LONGWORD, TRUE},
  {"TIMVCFAIL", SYI$_TIMVCFAIL, 4, IS_LONGWORD, TRUE},
  {"TMSCP_LOAD", SYI$_TMSCP_LOAD, 4, IS_LONGWORD, TRUE},
  {"TMSCP_SERVE_ALL", SYI$_TMSCP_SERVE_ALL, 4, IS_LONGWORD, TRUE},
  {"TTY_ALTALARM", SYI$_TTY_ALTALARM, 4, IS_LONGWORD, TRUE},
  {"TTY_ALTYPAHD", SYI$_TTY_ALTYPAHD, 4, IS_LONGWORD, TRUE},
  {"TTY_AUTOCHAR", SYI$_TTY_AUTOCHAR, 4, IS_LONGWORD, TRUE},
  {"TTY_BUF", SYI$_TTY_BUF, 4, IS_LONGWORD, TRUE},
  {"TTY_CLASSNAME", SYI$_TTY_CLASSNAME, 4, IS_LONGWORD, TRUE},
  {"TTY_DEFCHAR", SYI$_TTY_DEFCHAR, 4, IS_BITMAP, TRUE},
  {"TTY_DEFCHAR2", SYI$_TTY_DEFCHAR2, 4, IS_BITMAP, TRUE},
  {"TTY_DEFPORT", SYI$_TTY_DEFPORT, 4, IS_LONGWORD, TRUE},
  {"TTY_DIALTYPE", SYI$_TTY_DIALTYPE, 4, IS_LONGWORD, TRUE},
  {"TTY_DMASIZE", SYI$_TTY_DMASIZE, 4, IS_LONGWORD, TRUE},
  {"TTY_PARITY", SYI$_TTY_PARITY, 4, IS_LONGWORD, TRUE},
  {"TTY_RSPEED", SYI$_TTY_RSPEED, 4, IS_LONGWORD, TRUE},
  {"TTY_SCANDELTA", SYI$_TTY_SCANDELTA, 4, IS_LONGWORD, TRUE},
  {"TTY_SILOTIME", SYI$_TTY_SILOTIME, 4, IS_LONGWORD, TRUE},
  {"TTY_SPEED", SYI$_TTY_SPEED, 4, IS_LONGWORD, TRUE},
  {"TTY_TIMEOUT", SYI$_TTY_TIMEOUT, 4, IS_LONGWORD, TRUE},
  {"TTY_TYPAHDSZ", SYI$_TTY_TYPAHDSZ, 4, IS_LONGWORD, TRUE},
  {"UAFALTERNATE", SYI$_UAFALTERNATE, 4, IS_LONGWORD, TRUE},
  {"UDABURSTRATE", SYI$_UDABURSTRATE, 4, IS_LONGWORD, TRUE},
  {"USERD1", SYI$_USERD1, 4, IS_LONGWORD, TRUE},
  {"USERD2", SYI$_USERD2, 4, IS_LONGWORD, TRUE},
  {"USER3", SYI$_USER3, 4, IS_LONGWORD, TRUE},
  {"USER4", SYI$_USER4, 4, IS_LONGWORD, TRUE},
  {"VAXCLUSTER", SYI$_VAXCLUSTER, 4, IS_LONGWORD, TRUE},
  {"VECTOR_MARGIN", SYI$_VECTOR_MARGIN, 4, IS_LONGWORD, TRUE},
  {"VECTOR_PROC", SYI$_VECTOR_PROC, 4, IS_LONGWORD, TRUE},
  {"VOTES", SYI$_VOTES, 4, IS_LONGWORD, TRUE},
  {"WS_OPA0", SYI$_WS_OPA0, 4, IS_LONGWORD, TRUE},
  {"XFMAXRATE", SYI$_XFMAXRATE, 4, IS_LONGWORD, TRUE},
  {"ZERO_LIST_HI", SYI$_ZERO_LIST_HI, 4, IS_LONGWORD, TRUE},
  {NULL, 0, 0, 0, 0}
};

char *MonthNames[12] = {
  "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep",
  "Oct", "Nov", "Dec"} ;

/* Globals to track how many different pieces of info we can return, as */
/* well as how much space we'd need to grab to store it. */
static int SysInfoCount = 0;
static int SysInfoMallocSize = 0;
static int SysParmCount = 0;
static int SysParmMallocSize = 0;
static char LocalNodeName[255] = {""};
static short LocalNodeNameLen;
static long LocalNodeCSID;
static short LocalNodeCSIDLen;

void
tote_up_info_count()
{
  for(SysInfoCount = 0; SysInfoList[SysInfoCount].SysInfoName;
      SysInfoCount++) {
    /* While we're here, we might as well get a generous estimate of how */
    /* much space we'll need for all the buffers */
    SysInfoMallocSize += SysInfoList[SysInfoCount].BufferLen;
    /* Add in a couple extra, just to be safe */
    SysInfoMallocSize += 8;
  }
}    

void
tote_up_parm_count()
{
  for(SysParmCount = 0; SysParmList[SysParmCount].SysParmName;
      SysParmCount++) {
    /* While we're here, we might as well get a generous estimate of how */
    /* much space we'll need for all the buffers */
    SysParmMallocSize += SysParmList[SysInfoCount].BufferLen;
    /* Add in a couple extra, just to be safe */
    SysParmMallocSize += 8;
  }
}    

/* This routine makes a quickie call to getsyi to grab the local nodename */
/* and csid. */
void
set_local_node_name()
{
  short status;
  if (!LocalNodeName[0]) {
    ITMLST NodeInfoFetch[3];
    Zero(&NodeInfoFetch[0], 3, ITMLST);
    init_itemlist(&NodeInfoFetch[0], 255, SYI$_NODENAME, LocalNodeName,
                  &LocalNodeNameLen);
    init_itemlist(&NodeInfoFetch[1], 255, SYI$_NODENAME, &LocalNodeCSID,
                  &LocalNodeCSIDLen);
    status = sys$getsyiw(NULL, NULL, NULL, &NodeInfoFetch[0], 0, NULL, 0);
    
    /* Stick in a trailing null, just to be sure */
    LocalNodeName[LocalNodeNameLen] = 0;
  }
}

/* This routine takes a SYI item list ID and the value that wants to be */
/* de-enumerated and returns a pointer to an SV with the de-enumerated name */
/* in it */
SV *
enum_name(long syi_entry, long val_to_deenum)
{
  SV *WorkingSV = newSV(10);
  char ErrorMessage[255];
  switch (syi_entry) {
  case SYI$_ARCH_TYPE:
    switch(val_to_deenum) {
    case 1:
      sv_setpv(WorkingSV, "VAX");
      break;
    case 2:
      sv_setpv(WorkingSV, "Alpha");
      break;
    default:
      sv_setpv(WorkingSV, "Unknown Architecture");
      break;
    }
    break;
#ifdef SYI$_SYSTYPE
  case SYI$_SYSTYPE:
    switch(val_to_deenum) {
    case 2:
      sv_setpv(WorkingSV, "DEC 4000");
      break;
    case 3:
      sv_setpv(WorkingSV, "DEC 7000 or Dec 10000");
      break;
    case 4:
      sv_setpv(WorkingSV, "DEC 3000");
      break;
    default:
      sv_setpv(WorkingSV, "Unknown Architecture");
      break;
    }
    break;
#endif
  case SYI$_CPUTYPE:
  case SYI$_REAL_CPUTYPE:
    switch(val_to_deenum) {
    case 2:
      sv_setpv(WorkingSV, "DECchip 21064");
      break;
    default:
      sv_setpv(WorkingSV, "Unknown CPU Type");
      break;
    }
    break;
  case SYI$_CPU: 
    switch(val_to_deenum) {
    case PR$_SID_TYP730:
      sv_setpv(WorkingSV, "VAX-11/730");
      break;
    case PR$_SID_TYP750:
      sv_setpv(WorkingSV, "VAX-11/750");
      break;
    case PR$_SID_TYP780:
      sv_setpv(WorkingSV, "VAX-11/780, 785");
      break;
    case PR$_SID_TYPUV2:
      sv_setpv(WorkingSV, "VAXstation II, II/GPX, or MicroVAX II");
      break;
    case PR$_SID_TYP_NOTAVAX:
      sv_setpv(WorkingSV, "Not a VAX");
      break;
    default:
      sv_setpv(WorkingSV, "Unknown VAX");
      break;
    }
    break;
  default:
    sprintf(ErrorMessage, "Unknown enum %li", syi_entry);
    sv_setpv(WorkingSV, ErrorMessage);
    break;
  }

  return WorkingSV;
}

MODULE = VMS::SysInfo		PACKAGE = VMS::SysInfo		

void
sys_info_names(NodeName="")
   char * NodeName
   CODE:
{
  int i;
  int LocalNode;
  struct dsc$descriptor_s NodeNameDesc;
  char NodeNameBuffer[255];
  short NodeNameBufferLen;

  /* Have we ever gotten the local node name? If not, go for it */
  if (!*LocalNodeName) {
    set_local_node_name();
  }
  
  /* Are we local? */
  if ((!*NodeName) || !strcmp(NodeName, LocalNodeName))
    LocalNode = TRUE;
  else
    LocalNode = FALSE;
  
  for (i=0; SysInfoList[i].SysInfoName; i++) {

    /* Are we local? If not, skip local items */
    if ((!LocalNode) && (SysInfoList[i].LocalOnly))
      continue;
    XPUSHs(sv_2mortal(newSVpv(SysInfoList[i].SysInfoName, 0)));
  }
}

SV *
get_one_sys_info_item(infoname, NodeName="")
     SV *infoname
     char * NodeName;
   CODE:
{     
  int i;
  char *ReturnStringBuffer;            /* Return buffer pointer for strings */
  char ReturnByteBuffer;               /* Return buffer for bytes */
  unsigned short ReturnWordBuffer;     /* Return buffer for words */
  unsigned long ReturnLongWordBuffer;  /* Return buffer for longwords */
  unsigned short BufferLength;
  unsigned __int64 ReturnQuadWordBuffer;
  int status;
  unsigned short ReturnedTime[7];
  char AsciiTime[100];
  char QuadWordString[65];
  int LocalNode;
  struct dsc$descriptor_s NodeNameDesc;
  char NodeNameBuffer[255];
  short NodeNameBufferLen;
  
  /* Have we ever gotten the local node name? If not, go for it */
  if (!*LocalNodeName) {
    set_local_node_name();
  }

  /* Are we local? */
  if ((!*NodeName) || !strcmp(NodeName, LocalNodeName))
    LocalNode = TRUE;
  else
    LocalNode = FALSE;
  
  for (i = 0; SysInfoList[i].SysInfoName; i++) {
    if (strEQ(SysInfoList[i].SysInfoName, SvPV(infoname, na))) {
      break;
    }
  }

  /* Did we find a match? If not, complain and exit */
  if (SysInfoList[i].SysInfoName == NULL) {
    warn("Invalid sys info item");
    ST(0) = &sv_undef;
  } else {
    /* Did they ask for something we can get? */
    if ((!LocalNode) && (SysInfoList[i].LocalOnly)) {
      warn("Local info for remote node requested");
      ST(0) = &sv_undef;
    } else {
      /* allocate our item list */
      ITMLST OneItem[2];
      
      /* Copy the node name (whichever we're using) to someplace fixed */
      if (LocalNode) {
        strncpy(NodeNameBuffer, LocalNodeName, LocalNodeNameLen);
        NodeNameBufferLen = LocalNodeNameLen;
      } else {
        strcpy(NodeNameBuffer, NodeName);
        NodeNameBufferLen = strlen(NodeNameBuffer);
      }
      
      /* Build a string descriptor for the node name */
      NodeNameDesc.dsc$a_pointer = NodeNameBuffer;
      NodeNameDesc.dsc$w_length = NodeNameBufferLen;
      NodeNameDesc.dsc$b_dtype = DSC$K_DTYPE_T;
      NodeNameDesc.dsc$b_class = DSC$K_CLASS_S;
      
      /* Clear the buffer */
      Zero(&OneItem[0], 2, ITMLST);
      
      /* Fill in the itemlist depending on the return type */
      switch(SysInfoList[i].ReturnType) {
      case IS_STRING:
      case IS_STRANGE:
      case IS_VMSDATE:
        /* Allocate the return data buffer and zero it. Can be oddly sized, */
        /* so we use the system malloc instead of New */
        ReturnStringBuffer = malloc(SysInfoList[i].BufferLen);
        memset(ReturnStringBuffer, 0, SysInfoList[i].BufferLen);
        
        /* Fill in the item list */
        init_itemlist(&OneItem[0], SysInfoList[i].BufferLen,
                      SysInfoList[i].SYIValue, ReturnStringBuffer,
                      &BufferLength);
        
        /* Done */
        break;
        
      case IS_QUADWORD:
        /* Fill in the item list */
        init_itemlist(&OneItem[0], SysInfoList[i].BufferLen,
                      SysInfoList[i].SYIValue, &ReturnQuadWordBuffer,
                      &BufferLength);
        break;
        
      case IS_WORD:
        /* Fill in the item list */
        init_itemlist(&OneItem[0], SysInfoList[i].BufferLen,
                      SysInfoList[i].SYIValue, &ReturnWordBuffer,
                      &BufferLength);
        break;
        
      case IS_BYTEBOOL:
        /* Fill in the item list */
        init_itemlist(&OneItem[0], SysInfoList[i].BufferLen,
                      SysInfoList[i].SYIValue, &ReturnByteBuffer,
                      &BufferLength);
        break;
        
      case IS_ENUM:
      case IS_BITMAP:
      case IS_LONGWORD:
        /* Fill in the item list */
        init_itemlist(&OneItem[0], SysInfoList[i].BufferLen,
                      SysInfoList[i].SYIValue, &ReturnLongWordBuffer,
                      &BufferLength);
        break;
        
      default:
        warn("Unknown item return type");
        ST(0) = &sv_undef;
        return;
      }
      
      /* Make the call */
      status = sys$getsyiw(NULL, NULL, &NodeNameDesc, OneItem, 0, NULL, 0);
      
      /* Ok? */
      if (status == SS$_NORMAL) {
        /* Guess so. Grab the data and return it */
        switch(SysInfoList[i].ReturnType) {
        case IS_STRING:
          ST(0) = sv_2mortal(newSVpv(ReturnStringBuffer, 0));
          /* Give back the buffer */
          free(ReturnStringBuffer);
          break;
        case IS_QUADWORD:
          sprintf(QuadWordString, "%llu", ReturnQuadWordBuffer);
          ST(0) = sv_2mortal(newSVpv(QuadWordString, 0));
          break;
        case IS_VMSDATE:
          sys$numtim(ReturnedTime, ReturnStringBuffer);
          sprintf(AsciiTime, "%02hi-%s-%hi %02hi:%02hi:%02hi.%hi",
                  ReturnedTime[2], MonthNames[ReturnedTime[1] - 1],
                  ReturnedTime[0], ReturnedTime[3], ReturnedTime[4],
                  ReturnedTime[5], ReturnedTime[6]);
          ST(0) = sv_2mortal(newSVpv(AsciiTime, 0));
          free(ReturnStringBuffer);
          break;
        case IS_ENUM:
          ST(0) = enum_name(SysInfoList[i].SYIValue, ReturnLongWordBuffer);
          break;
        case IS_BITMAP:
        case IS_LONGWORD:
          ST(0) =  sv_2mortal(newSViv(ReturnLongWordBuffer));
          break;
        case IS_WORD:
          ST(0) =  sv_2mortal(newSViv(ReturnWordBuffer));
          break;
        case IS_BYTEBOOL:
          if (ReturnByteBuffer)
            ST(0) = &sv_yes;
          else
            ST(0) = &sv_no;
          break;
        default:
          ST(0) = &sv_undef;
          break;
        }
      } else {
        SETERRNO(EVMSERR, status);
        ST(0) = &sv_undef;
        if (status == SS$_NOSUCHNODE) {
          warn("No node of that name in the cluster");
        }
        /* free up the buffer if we were looking for a string */
        if (SysInfoList[i].ReturnType == IS_STRING)
          free(ReturnStringBuffer);
      }
    }
  }
}

void
get_all_sys_info_items(NodeName="")
     char * NodeName
   CODE:
{
  ITMLST *ListOItems;
  unsigned short *ReturnLengths;
  long *TempLongPointer;
  short *TempWordPointer;
  char *TempBytePointer;
  __int64 *TempQuadPointer;
  FetchedItem *OurDataList;
  int i, status, TotalItemCount;
  HV *AllPurposeHV;
  unsigned short ReturnedTime[7];
  char AsciiTime[100];
  char QuadWordString[65];
  int LocalNode;
  struct dsc$descriptor_s NodeNameDesc;
  char NodeNameBuffer[255];
  short NodeNameBufferLen;
  
  /* Have we ever gotten the local node name? If not, go for it */
  if (!*LocalNodeName) {
    set_local_node_name();
  }
  
  /* Are we local? */
  if ((!*NodeName) || !strcmp(NodeName, LocalNodeName)) {
    LocalNode = TRUE;
  } else {
    LocalNode = FALSE;
  }
  
  /* Copy the node name (whichever we're using) to someplace fixed */
  if (LocalNode) {
    strncpy(NodeNameBuffer, LocalNodeName, LocalNodeNameLen);
    NodeNameBufferLen = LocalNodeNameLen;
  } else {
    strcpy(NodeNameBuffer, NodeName);
    NodeNameBufferLen = strlen(NodeNameBuffer);
  }
  
  /* Build a string descriptor for the node name */
  NodeNameDesc.dsc$a_pointer = NodeNameBuffer;
  NodeNameDesc.dsc$w_length = NodeNameBufferLen;
  NodeNameDesc.dsc$b_dtype = DSC$K_DTYPE_T;
  NodeNameDesc.dsc$b_class = DSC$K_CLASS_S;
      
  /* If we've not gotten the count of items, go get it now */
  if (SysInfoCount == 0) {
    tote_up_info_count();
  }
  
  /* We need room for our item list */
  ListOItems = malloc(sizeof(ITMLST) * (SysInfoCount + 1));
  memset(ListOItems, 0, sizeof(ITMLST) * (SysInfoCount + 1));
  OurDataList = malloc(sizeof(FetchedItem) * SysInfoCount);
  
  /* We also need room for the buffer lengths */
  ReturnLengths = malloc(sizeof(short) * SysInfoCount);
  
  /* Zero out the number of items we've put in the list */
  TotalItemCount = 0;
  
  /* Fill in the item list and the tracking list */
  for (i = 0; i < SysInfoCount; i++) {
    /* Are we local? If not, skip local items */
    if ((!LocalNode) && (SysInfoList[i].LocalOnly))
      continue;

    /* Allocate the return data buffer and zero it. Can be oddly
       sized, so we use the system malloc instead of New */
    OurDataList[TotalItemCount].ReturnBuffer =
      malloc(SysInfoList[i].BufferLen);
    memset(OurDataList[TotalItemCount].ReturnBuffer, 0,
           SysInfoList[i].BufferLen);
        
    /* Note some important stuff (like what we're doing) in our local */
    /* tracking array */
    OurDataList[TotalItemCount].ItemName = SysInfoList[i].SysInfoName;
    OurDataList[TotalItemCount].ReturnLength = &ReturnLengths[TotalItemCount];
    OurDataList[TotalItemCount].ReturnType = SysInfoList[i].ReturnType;
    OurDataList[TotalItemCount].ItemListEntry = i;
    
    /* Fill in the item list */
    init_itemlist(&ListOItems[TotalItemCount], SysInfoList[i].BufferLen,
                  SysInfoList[i].SYIValue,
                  OurDataList[TotalItemCount].ReturnBuffer,
                  &ReturnLengths[TotalItemCount]);

    /* Up the item count */
    TotalItemCount++;
  }

  /* Make the GETSYIW call */
  status = sys$getsyiw(NULL, NULL, &NodeNameDesc, ListOItems, 0, NULL, 0);

  /* Did it go OK? */
  if (status == SS$_NORMAL) {
    /* Looks like it */
    AllPurposeHV = newHV();
    for (i = 0; i < TotalItemCount; i++) {
      switch(OurDataList[i].ReturnType) {
      case IS_STRING:
        hv_store(AllPurposeHV, OurDataList[i].ItemName,
                 strlen(OurDataList[i].ItemName),
                 newSVpv(OurDataList[i].ReturnBuffer,
                         *OurDataList[i].ReturnLength), 0);
        break;
      case IS_VMSDATE:
        sys$numtim(ReturnedTime, OurDataList[i].ReturnBuffer);
        sprintf(AsciiTime, "%02hi-%s-%hi %02hi:%02hi:%02hi.%hi",
                ReturnedTime[2], MonthNames[ReturnedTime[1] - 1],
                ReturnedTime[0], ReturnedTime[3], ReturnedTime[4],
                ReturnedTime[5], ReturnedTime[6]);
        hv_store(AllPurposeHV, OurDataList[i].ItemName,
                 strlen(OurDataList[i].ItemName),
                 newSVpv(AsciiTime, 0), 0);
        break;
      case IS_ENUM:
        TempLongPointer = OurDataList[i].ReturnBuffer;
        hv_store(AllPurposeHV, OurDataList[i].ItemName,
                 strlen(OurDataList[i].ItemName),
                 enum_name(SysInfoList[OurDataList[i].ItemListEntry].SYIValue,
                           *TempLongPointer), 0);
        break;
      case IS_BITMAP:
      case IS_LONGWORD:
        TempLongPointer = OurDataList[i].ReturnBuffer;
        hv_store(AllPurposeHV, OurDataList[i].ItemName,
                 strlen(OurDataList[i].ItemName),
                 newSViv(*TempLongPointer), 0);
        break;
      case IS_WORD:
        TempWordPointer = OurDataList[i].ReturnBuffer;
        hv_store(AllPurposeHV, OurDataList[i].ItemName,
                 strlen(OurDataList[i].ItemName),
                 newSViv(*TempWordPointer), 0);
        break;
      case IS_BYTEBOOL:
        TempBytePointer = OurDataList[i].ReturnBuffer;
        if (*TempBytePointer)
          hv_store(AllPurposeHV, OurDataList[i].ItemName,
                   strlen(OurDataList[i].ItemName), &sv_yes, 0);
        else
          hv_store(AllPurposeHV, OurDataList[i].ItemName,
                   strlen(OurDataList[i].ItemName), &sv_no, 0);
        break;
      case IS_QUADWORD:
        TempQuadPointer = OurDataList[i].ReturnBuffer;
        sprintf(QuadWordString, "%llu", *TempQuadPointer);
        hv_store(AllPurposeHV, OurDataList[i].ItemName,
                 strlen(OurDataList[i].ItemName),
                 newSVpv(QuadWordString, 0), 0);
        break;
        
      }
    }
    ST(0) = newRV_noinc((SV *) AllPurposeHV);
  } else {
    /* I think we failed */
    SETERRNO(EVMSERR, status);
    ST(0) = &sv_undef;
    
    /* An obvious failure? */
    if (status == SS$_NOSUCHNODE) {
      warn("No node of that name in the cluster");
    }
  }

  /* Free up our allocated memory */
  for(i = 0; i < TotalItemCount; i++) {
    free(OurDataList[i].ReturnBuffer);
  }
  free(OurDataList);
  free(ReturnLengths);
  free(ListOItems);
}

SV *
decode_sys_info_bitmap(InfoName, BitmapValue)
     char *InfoName
     int BitmapValue
   CODE:
{
  HV *AllPurposeHV;
  if (!strcmp(InfoName, "")) {
    AllPurposeHV = newHV();
    bit_test(AllPurposeHV, PRC$M_TCB, "TCB", BitmapValue);
  } else {
  if (!strcmp(InfoName, "")) {
    AllPurposeHV = newHV();
  } else {
  if (!strcmp(InfoName, "")) {
    AllPurposeHV = newHV();
  } else {
  if (!strcmp(InfoName, "")) {
    AllPurposeHV = newHV();
  } else {
  if (!strcmp(InfoName, "")) {
    AllPurposeHV = newHV();
  } else {
  if (!strcmp(InfoName, "")) {
    AllPurposeHV = newHV();
  } else {
  if (!strcmp(InfoName, "")) {
    AllPurposeHV = newHV();
  } else {
  if (!strcmp(InfoName, "")) {
     AllPurposeHV = newHV();
   }}}}}}}} 
  if (AllPurposeHV) {
    ST(0) = (SV *)AllPurposeHV;
  } else {
    ST(0) = &sv_undef;
  }
}

void
sys_parm_names()
   CODE:
{
  int i;
  for (i=0; SysParmList[i].SysParmName; i++) {
    XPUSHs(sv_2mortal(newSVpv(SysParmList[i].SysParmName, 0)));
  }
}

SV *
get_one_sys_parm_item(infoname)
     SV *infoname
   CODE:
{     
  int i;
  char *ReturnStringBuffer;            /* Return buffer pointer for strings */
  char ReturnByteBuffer;               /* Return buffer for bytes */
  unsigned short ReturnWordBuffer;     /* Return buffer for words */
  unsigned long ReturnLongWordBuffer;  /* Return buffer for longwords */
  unsigned short BufferLength;
  unsigned __int64 ReturnQuadWordBuffer;
  int status;
  unsigned short ReturnedTime[7];
  char AsciiTime[100];
  char QuadWordString[65];
  
  for (i = 0; SysParmList[i].SysParmName; i++) {
    if (strEQ(SysParmList[i].SysParmName, SvPV(infoname, na))) {
      break;
    }
  }

  /* Did we find a match? If not, complain and exit */
  if (SysParmList[i].SysParmName == NULL) {
    warn("Invalid sys info item");
    ST(0) = &sv_undef;
  } else {
    /* allocate our item list */
    ITMLST OneItem[2];
    
    /* Clear the buffer */
    Zero(&OneItem[0], 2, ITMLST);
    
    /* Fill in the itemlist depending on the return type */
    switch(SysParmList[i].ReturnType) {
    case IS_STRING:
    case IS_STRANGE:
    case IS_VMSDATE:
      /* Allocate the return data buffer and zero it. Can be oddly sized, */
      /* so we use the system malloc instead of New */
      ReturnStringBuffer = malloc(SysParmList[i].BufferLen);
      memset(ReturnStringBuffer, 0, SysParmList[i].BufferLen);
      
      /* Fill in the item list */
      init_itemlist(&OneItem[0], SysParmList[i].BufferLen,
                    SysParmList[i].SYIValue, ReturnStringBuffer,
                    &BufferLength);
      
      /* Done */
      break;
      
    case IS_QUADWORD:
      /* Fill in the item list */
      init_itemlist(&OneItem[0], SysParmList[i].BufferLen,
                    SysParmList[i].SYIValue, &ReturnQuadWordBuffer,
                    &BufferLength);
      break;
      
    case IS_WORD:
      /* Fill in the item list */
      init_itemlist(&OneItem[0], SysParmList[i].BufferLen,
                    SysParmList[i].SYIValue, &ReturnWordBuffer,
                    &BufferLength);
      break;
      
    case IS_BYTEBOOL:
      /* Fill in the item list */
      init_itemlist(&OneItem[0], SysParmList[i].BufferLen,
                    SysParmList[i].SYIValue, &ReturnByteBuffer,
                    &BufferLength);
      break;
      
    case IS_ENUM:
    case IS_BITMAP:
    case IS_LONGWORD:
      /* Fill in the item list */
      init_itemlist(&OneItem[0], SysParmList[i].BufferLen,
                    SysParmList[i].SYIValue, &ReturnLongWordBuffer,
                    &BufferLength);
      break;
      
    default:
      warn("Unknown item return type");
      ST(0) = &sv_undef;
      return;
    }
    
    /* Make the call */
    status = sys$getsyiw(NULL, NULL, NULL, OneItem, 0, NULL, 0);
      
      /* Ok? */
    if (status == SS$_NORMAL) {
      /* Guess so. Grab the data and return it */
      switch(SysParmList[i].ReturnType) {
      case IS_STRING:
        ST(0) = sv_2mortal(newSVpv(ReturnStringBuffer, 0));
        /* Give back the buffer */
        free(ReturnStringBuffer);
        break;
      case IS_QUADWORD:
        sprintf(QuadWordString, "%llu", ReturnQuadWordBuffer);
        ST(0) = sv_2mortal(newSVpv(QuadWordString, 0));
        break;
      case IS_VMSDATE:
        sys$numtim(ReturnedTime, ReturnStringBuffer);
        sprintf(AsciiTime, "%02hi-%s-%hi %02hi:%02hi:%02hi.%hi",
                ReturnedTime[2], MonthNames[ReturnedTime[1] - 1],
                ReturnedTime[0], ReturnedTime[3], ReturnedTime[4],
                ReturnedTime[5], ReturnedTime[6]);
        ST(0) = sv_2mortal(newSVpv(AsciiTime, 0));
        free(ReturnStringBuffer);
        break;
      case IS_ENUM:
        ST(0) = enum_name(SysParmList[i].SYIValue, ReturnLongWordBuffer);
        break;
      case IS_BITMAP:
      case IS_LONGWORD:
        ST(0) =  sv_2mortal(newSViv(ReturnLongWordBuffer));
        break;
      case IS_WORD:
        ST(0) =  sv_2mortal(newSViv(ReturnWordBuffer));
        break;
      case IS_BYTEBOOL:
        if (ReturnByteBuffer)
          ST(0) = &sv_yes;
        else
          ST(0) = &sv_no;
        break;
      default:
        ST(0) = &sv_undef;
        break;
      }
    } else {
      SETERRNO(EVMSERR, status);
      ST(0) = &sv_undef;
      /* free up the buffer if we were looking for a string */
      if (SysParmList[i].ReturnType == IS_STRING)
        free(ReturnStringBuffer);
    }
  }
}

void
get_all_sys_parm_items()
   CODE:
{
  ITMLST *ListOItems;
  unsigned short *ReturnLengths;
  long *TempLongPointer;
  short *TempWordPointer;
  char *TempBytePointer;
  __int64 *TempQuadPointer;
  FetchedItem *OurDataList;
  int i, status, TotalItemCount;
  HV *AllPurposeHV;
  unsigned short ReturnedTime[7];
  char AsciiTime[100];
  char QuadWordString[65];
      
  /* If we've not gotten the count of items, go get it now */
  if (SysParmCount == 0) {
    tote_up_parm_count();
  }
  
  /* We need room for our item list */
  ListOItems = malloc(sizeof(ITMLST) * (SysParmCount + 1));
  memset(ListOItems, 0, sizeof(ITMLST) * (SysParmCount + 1));
  OurDataList = malloc(sizeof(FetchedItem) * SysParmCount);
  
  /* We also need room for the buffer lengths */
  ReturnLengths = malloc(sizeof(short) * SysParmCount);
  
  /* Zero out the number of items we've put in the list */
  TotalItemCount = 0;
  
  /* Fill in the item list and the tracking list */
  for (i = 0; i < SysParmCount; i++) {
    /* Allocate the return data buffer and zero it. Can be oddly
       sized, so we use the system malloc instead of New */
    OurDataList[TotalItemCount].ReturnBuffer =
      malloc(SysParmList[i].BufferLen);
    memset(OurDataList[TotalItemCount].ReturnBuffer, 0,
           SysParmList[i].BufferLen);
        
    /* Note some important stuff (like what we're doing) in our local */
    /* tracking array */
    OurDataList[TotalItemCount].ItemName = SysParmList[i].SysParmName;
    OurDataList[TotalItemCount].ReturnLength = &ReturnLengths[TotalItemCount];
    OurDataList[TotalItemCount].ReturnType = SysParmList[i].ReturnType;
    OurDataList[TotalItemCount].ItemListEntry = i;
    
    /* Fill in the item list */
    init_itemlist(&ListOItems[TotalItemCount], SysParmList[i].BufferLen,
                  SysParmList[i].SYIValue,
                  OurDataList[TotalItemCount].ReturnBuffer,
                  &ReturnLengths[TotalItemCount]);

    /* Up the item count */
    TotalItemCount++;
  }

  /* Make the GETSYIW call */
  status = sys$getsyiw(NULL, NULL, NULL, ListOItems, 0, NULL, 0);

  /* Did it go OK? */
  if (status == SS$_NORMAL) {
    /* Looks like it */
    AllPurposeHV = newHV();
    for (i = 0; i < TotalItemCount; i++) {
      switch(OurDataList[i].ReturnType) {
      case IS_STRING:
        hv_store(AllPurposeHV, OurDataList[i].ItemName,
                 strlen(OurDataList[i].ItemName),
                 newSVpv(OurDataList[i].ReturnBuffer,
                         *OurDataList[i].ReturnLength), 0);
        break;
      case IS_VMSDATE:
        sys$numtim(ReturnedTime, OurDataList[i].ReturnBuffer);
        sprintf(AsciiTime, "%02hi-%s-%hi %02hi:%02hi:%02hi.%hi",
                ReturnedTime[2], MonthNames[ReturnedTime[1] - 1],
                ReturnedTime[0], ReturnedTime[3], ReturnedTime[4],
                ReturnedTime[5], ReturnedTime[6]);
        hv_store(AllPurposeHV, OurDataList[i].ItemName,
                 strlen(OurDataList[i].ItemName),
                 newSVpv(AsciiTime, 0), 0);
        break;
      case IS_ENUM:
        TempLongPointer = OurDataList[i].ReturnBuffer;
        hv_store(AllPurposeHV, OurDataList[i].ItemName,
                 strlen(OurDataList[i].ItemName),
                 enum_name(SysParmList[OurDataList[i].ItemListEntry].SYIValue,
                           *TempLongPointer), 0);
        break;
      case IS_BITMAP:
      case IS_LONGWORD:
        TempLongPointer = OurDataList[i].ReturnBuffer;
        hv_store(AllPurposeHV, OurDataList[i].ItemName,
                 strlen(OurDataList[i].ItemName),
                 newSViv(*TempLongPointer), 0);
        break;
      case IS_WORD:
        TempWordPointer = OurDataList[i].ReturnBuffer;
        hv_store(AllPurposeHV, OurDataList[i].ItemName,
                 strlen(OurDataList[i].ItemName),
                 newSViv(*TempWordPointer), 0);
        break;
      case IS_BYTEBOOL:
        TempBytePointer = OurDataList[i].ReturnBuffer;
        if (*TempBytePointer)
          hv_store(AllPurposeHV, OurDataList[i].ItemName,
                   strlen(OurDataList[i].ItemName), &sv_yes, 0);
        else
          hv_store(AllPurposeHV, OurDataList[i].ItemName,
                   strlen(OurDataList[i].ItemName), &sv_no, 0);
        break;
      case IS_QUADWORD:
        TempQuadPointer = OurDataList[i].ReturnBuffer;
        sprintf(QuadWordString, "%llu", *TempQuadPointer);
        hv_store(AllPurposeHV, OurDataList[i].ItemName,
                 strlen(OurDataList[i].ItemName),
                 newSVpv(QuadWordString, 0), 0);
        break;
        
      }
    }
    ST(0) = newRV_noinc((SV *) AllPurposeHV);
  } else {
    /* I think we failed */
    SETERRNO(EVMSERR, status);
    ST(0) = &sv_undef;
    
  }
  
  /* Free up our allocated memory */
  for(i = 0; i < TotalItemCount; i++) {
    free(OurDataList[i].ReturnBuffer);
  }
  free(OurDataList);
  free(ReturnLengths);
  free(ListOItems);
}

SV *
decode_sys_parm_bitmap(InfoName, BitmapValue)
     char *InfoName
     int BitmapValue
   CODE:
{
  HV *AllPurposeHV;
  if (!strcmp(InfoName, "")) {
    AllPurposeHV = newHV();
    bit_test(AllPurposeHV, PRC$M_TCB, "TCB", BitmapValue);
  } else {
  if (!strcmp(InfoName, "")) {
    AllPurposeHV = newHV();
  } else {
  if (!strcmp(InfoName, "")) {
    AllPurposeHV = newHV();
  } else {
  if (!strcmp(InfoName, "")) {
    AllPurposeHV = newHV();
  } else {
  if (!strcmp(InfoName, "")) {
    AllPurposeHV = newHV();
  } else {
  if (!strcmp(InfoName, "")) {
    AllPurposeHV = newHV();
  } else {
  if (!strcmp(InfoName, "")) {
    AllPurposeHV = newHV();
  } else {
  if (!strcmp(InfoName, "")) {
     AllPurposeHV = newHV();
   }}}}}}}} 
  if (AllPurposeHV) {
    ST(0) = (SV *)AllPurposeHV;
  } else {
    ST(0) = &sv_undef;
  }
}
