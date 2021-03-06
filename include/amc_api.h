/**
 * Copyright (c) 2009 Ma Can <ml.macana@gmail.com>
 *                           <macan@ncic.ac.cn>
 *
 * Armed with EMACS.
 * Time-stamp: <2012-05-16 17:21:28 macan>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 *
 */

#ifndef __AMC_API_H__
#define __AMC_API_H__

/* the general index structre between AMC client and MDS */
struct amc_index
{
#define INDEX_PUT       0x00000001
#define INDEX_GET       0x00000002
#define INDEX_MPUT      0x00000004
#define INDEX_MGET      0x00000008

#define INDEX_DEL       0x00000010
#define INDEX_UPDATE    0x00000020
#define INDEX_CUPDATE   0x00000040 /* conditional update */
#define INDEX_COMMIT    0x00000080

#define INDEX_SPUT      0x00000100
#define INDEX_SGET      0x00000200
#define INDEX_SDEL      0x00000300
#define INDEX_SUPDATE   0x00000400
#define INDEX_SCUPDATE  0x00000500
    u16 op;

#define INDEX_CU_EXIST          0x0080000
#define INDEX_CU_NOTEXIST       0x0040000
    u16 flag;
    int column;                 /* which column you want to get/put */

    u64 key;                    /* used to search in EH, should be unique */
    u64 sid;                    /* table slice id, may not precise */
    u64 tid;                    /* table id */

    u64 ptid;                   /* parent table id */
    u64 psalt;                  /* parent salt */
    void *data;                 /* pointer to data payload */
    u64 dlen;                   /* intransfer length of payload */
};

/* APIs */
int __core_main(int argc, char *argv[]);
void __core_exit(void);

int hvfs_lookup_root(void);
int hvfs_create_root(void);
int hvfs_create_table(char *name);
int hvfs_find_table(char *name, u64 *uuid, u64 *salt);
int hvfs_drop_table(char *name);
int hvfs_put(char *table, u64 key, char *value, int column);
int hvfs_get(char *table, u64 key, char **value, int column);
int hvfs_del(char *table, u64 key, int column);
int hvfs_update(char *table, u64 key, char *value, int column);
int hvfs_sput(char *table, char *key, char *value, int column);
int hvfs_sget(char *table, char *key, char **value, int column);
int hvfs_sdel(char *table, char *key, int column);
int hvfs_supdate(char *table, char *key, char *value, int column);

int hvfs_get_indirect(struct amc_index *iai, struct mu_column **mc);
int hvfs_sget_indirect(struct amc_index *iai, struct mu_column **mc);

#define LIST_OP_SCAN            0
#define LIST_OP_COUNT           1
#define LIST_OP_GREP            2
#define LIST_OP_GREP_COUNT      3
struct list_result
{
    void *arg;
    int cnt;
};
int hvfs_list(char *table, int op, char *arg);
int hvfs_commit(int id);
int hvfs_get_cluster(char *type);
char *hvfs_active_site(char *type);
int hvfs_online(char *type, int id);
int hvfs_offline(char *type, int id, int force);

/* APIs for Client */
struct hstat
{
    char *name;
    u64 puuid;                  /* parent uuid */
    union 
    {
        u64 psalt;              /* parent salt */
        u64 ssalt;              /* self salt */
    };
    u64 uuid;                   /* self uuid */
    u64 hash;                   /* self hash */
    struct mdu mdu;             /* self mdu */
    struct mu_column mc;
};

/* @data_back: It is a string return back to caller.
 *
 * The format of data_back is:
 * F1: puuid # for dir it is the self uuid
 * F2: psalt # for dir it is the self salt
 * F3: uuid # self uuid
 * F4: mdu.flags # mdu flags
 * F5: mdu.uid # mdu user id
 * F6: mdu.gid # mdu group id
 * F7: mdu.mode # mdu mode
 * F8: mdu.nlink # mdu nlink
 * F9: mdu.size # mdu saved file length
 * F10: mdu.dev # mdu saved dev
 * F11: mdu.atime # mdu saved access time
 * F12: mdu.ctime # mdu saved change time
 * F13: mdu.mtime # mdu saved modify time
 * F14: mdu.dtime # mdu saved delete time
 * F15: mdu.version # mdu saved version
 * F16: mdu.symname or llfs_ref # $REF_COLUMN$ or $fsid$rfino$ or symname
 * F17: column_no
 * F18: c->saved_itbid
 * F19: c->len
 * F20: c->offset
 */
int hvfs_stat(char *path, char *name, void **data_back);
int hvfs_create(char *path, char *name, void **data_back, u32 is_dir);
int hvfs_fupdate(char *path, char *name, void **data);
int hvfs_fdel(char *path, char *name, void **data, u32 is_dir);
int hvfs_readdir(char *path, char *name, void **data);
ssize_t hvfs_fread(char *path, char *name, int column, void **data, u64 *len);
int hvfs_fwrite(char *path, char *name, int column, void *data, 
                u64 len, u32 flag);
int hvfs_fcommit(int id);
int hvfs_reg_dtrigger(char *path, char *name, u16 priority, u16 where,
                      u32 type, void *data, size_t len);
int __hvfs_reg_dtrigger(struct hstat *, u16 priority, u16 where,
                        u32 type, void *data, size_t len);
int hvfs_cat_dtrigger(char *path, char *name, void **data);
int __hvfs_cat_dtrigger(struct hstat *, void **data);
int hvfs_clear_dtrigger(char *path, char *name);
int __hvfs_clear_dtrigger(struct hstat *);
int hvfs_statfs(void **data);
void hvfs_free(void *p);

struct pfile_handle;
typedef int (*ploop_func_t)(struct pfile_handle *, void **, size_t *);
int hvfs_pstat(struct pfile_handle *fh, void **data, size_t *size);
int hvfs_ploop(struct pfile_handle *fh, int nr, ploop_func_t pf, void **data,
    size_t *size);

/* internal APIs */
int __hvfs_stat(u64 puuid, u64 psalt, int column, struct hstat *hs);
int __hvfs_stat_ext(u64 puuid, u64 psalt, int column, u32 flag, 
                    struct hstat *hs);
int __hvfs_linkadd(u64 puuid, u64 psalt, int nlink, struct hstat *hs);
int __hvfs_linkadd_ext(u64 puuid, u64 psalt, int nlink, u32 flag,
                       struct hstat *hs);
int __hvfs_fill_root(struct hstat *hs);
int __hvfs_create(u64 puuid, u64 psalt, struct hstat *hs, 
                  u32 flag, struct mdu_update *imu);
int __hvfs_update(u64 puuid, u64 psalt, struct hstat *hs,
                  struct mdu_update *imu);
int __hvfs_unlink(u64 puuid, u64 psalt, struct hstat *hs);
int __hvfs_unlink_ext(u64 puuid, u64 psalt, u32 flag, struct hstat *hs);
ssize_t __hvfs_fread(struct hstat *hs, int column, void **data, 
                     struct column *c, u64 offset, u64 size);
int __hvfs_fwrite(struct hstat *hs, int column, u32 flag,
                  void *data, size_t len, struct column *c);
int __hvfs_fwritev(struct hstat *hs, int column, u32 flag,
                  struct iovec *iov, int iovlen, struct column *c);
int __hvfs_statfs(struct statfs *s, u64 dsite);
int __hvfs_is_empty_dir(u64 puuid, u64 psalt, struct hstat *hs);
int hvfs_analyse_storage(u64 site, int cmd, void *data, int *len);

/* Region for BRANCH subsystem */

/* BRANCH commands */
#define BRANCH_CMD_NOPE         0x00
#define BRANCH_CMD_PUSH         0x01
#define BRANCH_CMD_PULL         0x02
#define BRANCH_CMD_ACK          0x03
#define BRANCH_CMD_REPLICA      0x04
#define BRANCH_CMD_BULK_PUSH    0x05
#define BRANCH_CMD_ACK_REPLICA  0x06
#define BRANCH_CMD_ADJUST       0x07
#define BRANCH_CMD_GETBOR       0x08
#define BRANCH_CMD_SEARCH       0x09

struct branch_search_expr_tx
{
    u32 name_len, expr_len;
    u16 dbname_len, prefix_len;
    char data[0];
};

/* File handle returned by BRANCH subsystem */
struct pfile_handle
{
    u64 puuid;
    u64 uuid;
    u64 hash;
    char *name;                 /* if name is NULL, then uuid and hash must be
                                 * valid! */
};

#endif
