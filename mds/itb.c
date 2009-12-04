/**
 * Copyright (c) 2009 Ma Can <ml.macana@gmail.com>
 *                           <macan@ncic.ac.cn>
 *
 * Armed with EMACS.
 * Time-stamp: <2009-12-04 17:39:50 macan>
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

#include "hvfs.h"
#include "mdsl_api.h"
#include "xtable.h"
#include "xnet.h"
#include "mds.h"

void itb_index_rlock(struct itb_lock *l)
{
}

void itb_index_wlock(struct itb_lock *l)
{
}

void itb_index_runlock(struct itb_lock *l)
{
}

void itb_index_wunlock(struct itb_lock *l)
{
}

/* mds_read_itb
 *
 * Err convention: Kernel err-ptr convention
 */
struct itb *mds_read_itb(u64 puuid, u64 psalt, u64 itbid)
{
    struct storage_index si;
    struct storage_result *sr;
    struct xnet_msg *msg;
    struct chp *p;
    struct itb *i;
    int ret;

    si.sic.uuid = puuid;
    si.sic.arg0 = itbid;
    si.m.sm.len = 0;            /* no data */
    msg = xnet_alloc_msg(XNET_MSG_CACHE);
    if (!msg) {
        /* retry with slow method */
        msg = xnet_alloc_msg(XNET_MSG_NORMAL);
        if (!msg) {
            hvfs_err(mds, "xnet_alloc_msg() failed with %ld\n", 
                     PTR_ERR(msg));
            return (struct itb *)msg; /* return the err */
        }
    }
    p = ring_get_point(itbid, psalt, hmo.chring[CH_RING_MDSL]);
    if (IS_ERR(p)) {
        hvfs_err(mds, "ring_get_point() failed with %ld\n", PTR_ERR(p));
        return (struct itb *)p;
    }
    /* prepare the msg */
    xnet_msg_set_site(msg, p->site_id);
    xnet_msg_add_data(msg, &si, sizeof(si));
    xnet_msg_fill_cmd(msg, HVFS_MDS2MDSL_ITB, 0);
    
    ret = xnet_send(hmo.xc, msg);
    if (ret) {
        hvfs_err(mds, "xnet_send() failed with %d\n", ret);
        return ERR_PTR(ret);
    }
    /* ok, we get the reply: ITB.len is the length */
    sr = (struct storage_result *)(msg->pair->xm_data);
    if (sr->src.err)
        i = ERR_PTR(sr->src.err);
    else
        i = (struct itb *)(sr->data);
    xnet_free_msg(msg);

    return i;
}

/*
 * itb_add_ite()
 */
int itb_add_ite(struct itb *i, struct hvfs_index *hi)
{
    return 0;
}

/* 
 * itb_del_ite()
 */
void itb_del_ite(struct itb *i, struct ite *e)
{
}

/*
 * ITE unlink
 */
void ite_unlink(struct ite *e, struct itb *i)
{
    if (e->flag & ITE_FLAG_NORMAL) {
        /* normal file */
        e->s.mdu.nlink--;
        if (!e->s.mdu.nlink)
            e->flag = ((e->flag & ~ITE_STATE_MASK) | ITE_UNLINKED);
        else
            e->flag = ((e->flag & ~ITE_STATE_MASK) | ITE_SHADOW);
    } else if (e->flag & ITE_FLAG_LS) {
        /* FIXME: hard link file, nobody refer it, just delete it */
        itb_del_ite(i, e);
    }
}

/*
 * ITE update with HI
 */
void ite_update(struct hvfs_index *hi, struct ite *e)
{
    if (hi->flag & INDEX_MDU_UPDATE) {
        /* hi->data is mdu_update */
        struct mdu_update *mu = (struct mdu_update *)hi->data;

        if (mu->valid & MU_MODE)
            e->s.mdu.mode = mu->mode;
        if (mu->valid & MU_UID)
            e->s.mdu.uid = mu->uid;
        if (mu->valid & MU_GID)
            e->s.mdu.gid = mu->gid;
        if (mu->valid & MU_FLAG_ADD)
            e->s.mdu.flags |= mu->flags;
        if (mu->valid & MU_FLAG_CLR)
            e->s.mdu.flags &= ~(mu->flags);
        if (mu->valid & MU_ATIME)
            e->s.mdu.atime = mu->atime;
        if (mu->valid & MU_CTIME)
            e->s.mdu.ctime = mu->ctime;
        if (mu->valid & MU_MTIME)
            e->s.mdu.mtime = mu->mtime;
        if (mu->valid & MU_VERSION)
            e->s.mdu.version = mu->version;
        if (mu->valid & MU_SIZE)
            e->s.mdu.size = mu->size;
        if (mu->valid & MU_COLUMN) {
            struct mu_column *mc = (struct mu_column *)(
                hi->data + sizeof(struct mdu_update));
            int i;

            for (i = 0; i < mu->column_no; i++) {
                /* copy to the dst location */
                e->column[(mc + i)->cno] = (mc + i)->c;
            }
        }
    } else if (hi->flag & INDEX_CREATE_COPY) {
        /* hi->data is MDU */
        memcpy(&e->s.mdu, hi->data, sizeof(struct mdu));
    } else if (hi->flag & INDEX_CREATE_LINK) {
        /* hi->data is LS */
        memcpy(&e->s.ls, hi->data, sizeof(struct link_source));
    }
}

/*
 * ITE match
 *
 * Return: ITE_MATCH_MISS/ITE_MATCH_HIT
 */
inline int ite_match(struct ite *e, struct hvfs_index *hi)
{
    /* compare the name or uuid */
    if (hi->flag & INDEX_ITE_SHADOW) { 
        if (((e->flag & ITE_STATE_MASK) != ITE_SHADOW) && 
            ((e->flag & ITE_STATE_MASK) != ITE_UNLINKED))
            return ITE_MATCH_MISS;
    }
    
    if ((hi->flag & INDEX_ITE_ACTIVE) && ((e->flag & ITE_STATE_MASK) != ITE_ACTIVE))
        return ITE_MATCH_MISS;
    
    if ((hi->flag & INDEX_BY_UUID_D) || (hi->flag & INDEX_BY_UUID_F)) {
        if (e->uuid == hi->uuid && e->hash == hi->hash) {
            return ITE_MATCH_HIT;
        } else
            return ITE_MATCH_MISS;
    } else if (hi->flag & INDEX_BY_NAME) {
        if (strncmp(e->s.name, hi->name, hi->len) == 0) {
            return ITE_MATCH_HIT;
        } else
            return ITE_MATCH_MISS;
    } else {
        return ITE_MATCH_MISS;
    }
}

/* get_free_itb()
 */
struct itb *get_free_itb()
{
    struct itb *n;
    struct list_head *l = NULL;

    xlock_lock(&hmo.ic.lock);
    if (!list_empty(&hmo.ic.lru)) {
        l = hmo.ic.lru.next;
        ASSERT(l != &hmo.ic.lru, mds);
        list_del(l);
    }
    xlock_unlock(&hmo.ic.lock);

    if (l) {
        /* remove from the CBHT */
        n = (struct itb *)(list_entry(l, struct itbh, list));
        if (!hlist_unhashed(&n->h.cbht))
            mds_cbht_del(&hmo.cbht, n);
        memset(n, 0, sizeof(struct itb));
    } else {
        /* try to malloc() one */
        n = xzalloc(sizeof(struct itb) + sizeof(struct ite) * ITB_SIZE);
        if (!n) {
            hvfs_err(mds, "xzalloc() ITB failed\n");
            return NULL;
        }
    }

    n->h.len = sizeof(struct itb);
    n->h.adepth = ITB_DEPTH;
    n->h.flag = ITB_ACTIVE;       /* 0 */
    n->h.state = ITB_STATE_CLEAN; /* 0 */
    xrwlock_init(&n->h.lock);
    INIT_HLIST_NODE(&n->h.cbht);
    INIT_LIST_HEAD(&n->h.list);

    return n;
}

/* itb_free()
 */
void itb_free(struct itb *i)
{
    xlock_lock(&hmo.ic.lock);
    list_add_tail(&i->h.list, &hmo.ic.lru);
    xlock_unlock(&hmo.ic.lock);
}

/* ITB COW
 */
struct itb *itb_cow(struct itb *itb)
{
    struct itb *n;

    do {
        n = get_free_itb();
    } while (!n && ({xsleep(10); 1;}));

    memcpy(n, itb, itb->h.len);
    xrwlock_init(&n->h.lock);
    INIT_HLIST_NODE(&n->h.cbht);
    INIT_LIST_HEAD(&n->h.list);
    
    return n;
}

/**
 * ITB Dirty
 *
 * @itb:ITB
 * @t:  TXG
 * @be: bucket_entry
 *
 * Note: dirty and cow the ITB as needed; return the dirtied ITB for using
 */
struct itb *itb_dirty(struct itb *itb, struct hvfs_txg *t)
{
    if (t->txg == itb->h.txg) {
        /* ITB accessed in this TXG */
        if (itb->h.state == ITB_STATE_DIRTY)
            return itb;
        else {
            hvfs_err(mds, "Hoo, ITB state 0x%x in TXG: 0x%lx\n", itb->h.state, 
                     t->txg);
            itb->h.state = ITB_STATE_DIRTY;
        }
    } else if (t->txg == itb->h.txg + 1) {
        /* ITB accessed in the last TXG */
        if (itb->h.state == ITB_STATE_WBED || itb->h.state == ITB_STATE_CLEAN) {
            /* clean or already write-backed, free to use */
            itb->h.txg = t->txg;
            itb->h.state = ITB_STATE_DIRTY;
            txg_add_itb(t, itb);
        } else if (itb->h.state == ITB_STATE_DIRTY) {
            /* need COW */
            struct itb *n;
            struct bucket_entry *be = itb->h.be;
            int should_retry = 0;

            n = itb_cow(itb);   /* itb_cow always success */

            if (hlist_unhashed(&itb->h.cbht)) {
                /* this ITB is stale */
                itb_free(n);
                xrwlock_runlock(&itb->h.lock);
                return NULL;
            }
            
            xrwlock_wlock(&be->lock);
            /* unlock the original ITB */
            xrwlock_runlock(&itb->h.lock);
            xrwlock_wlock(&itb->h.lock); /* change to WLOCK */

            if (!hlist_unhashed(&itb->h.cbht)) {
                hlist_del_init(&itb->h.cbht);
                hlist_add_head(&n->h.cbht, &be->h);
                n->h.be = itb->h.be;
            } else {
                should_retry = 1;
            }

            xrwlock_wunlock(&itb->h.lock);
            xrwlock_wunlock(&be->lock);

            if (should_retry) {
                itb_free(n);
                return NULL;
            }
            
            xrwlock_rlock(&n->h.lock);
            n->h.txg = t->txg;
            n->h.state = ITB_STATE_DIRTY;
            txg_add_itb(t, n);
            itb = n;
        }
    } else if (t->txg > itb->h.txg + 1) {
        /* ITB not accessed in the last TXG */
        hvfs_info(mds, "Note that we must promise no pending WB on the TXG: "
                  "0x%lx\n", itb->h.txg);
    }

    return itb;
}

/**
 * Search ITE in the ITB, matched by hvfs_index
 *
 * Err Convention: 0 means no error, other MINUS number means error
 */
int itb_search(struct hvfs_index *hi, struct itb* itb, void *data, 
               struct hvfs_txg *txg)
{
    u64 offset = hi->hash & ((1 << itb->h.adepth) - 1);
    struct itb_index *ii;
    struct itb_lock *l;
    int ret = 0;

    /* get the lock */
    l = &itb->lock[offset / ITB_LOCK_GRANULARITY];
    if (hi->flag & INDEX_LOOKUP)
        itb_index_rlock(l);
    else
        itb_index_wlock(l);
    
    ret = -ENOENT;
    while (offset < (1 << (itb->h.adepth + 1))) {
        ii = &itb->index[offset];
        if (ii->flag == ITB_INDEX_FREE)
            break;
        ret = ite_match(&itb->ite[ii->entry], hi);

        if (ii->flag == ITB_INDEX_UNIQUE) {
            if (ret == ITE_MATCH_MISS) {
                break;
            }
        } else {
            /* CONFLICT & OVERFLOW */
            if (ret == ITE_MATCH_MISS) {
                offset = ii->conflict;
                continue;
            }
        }
        /* OK, found it, already lock it then do xxx on it */
        hvfs_debug(mds, "OK, the ITE do exist in the ITB.\n");
        if (hi->flag & INDEX_LOOKUP) {
            /* read MDU to buffer */
            memcpy(data, &(itb->ite[ii->entry].g), HVFS_MDU_SIZE);
        } else if (hi->flag & INDEX_CREATE) {
            /* already exist, so... */
            if (!hi->flag & INDEX_CREATE_FORCE) {
                /* should return -EEXIST */
                ret = -EEXIST;
                goto out;
            }
            /* FIXME: ok, forcely do it */
            if (hi->flag & INDEX_CREATE_DIR) {
                hvfs_debug(mds, "Forcely create dir now ... should no happen?\n");
            } else if (hi->flag & INDEX_CREATE_COPY) {
                hvfs_debug(mds, "Forcely create with MDU ...\n");
                itb = itb_dirty(itb, txg);
                if (!itb) {
                    ret = -EAGAIN;
                    goto out;
                }
                ite_update(hi, &itb->ite[ii->entry]);
            } else if (hi->flag & INDEX_CREATE_LINK) {
                hvfs_debug(mds, "Forcely create hard link ...\n");
                itb = itb_dirty(itb, txg);
                if (!itb) {
                    ret = -EAGAIN;
                    goto out;
                }
                ite_update(hi, &itb->ite[ii->entry]);
            }
        } else if (hi->flag & INDEX_MDU_UPDATE) {
            /* setattr, no failure */
            hvfs_debug(mds, "Find the ITE and update the MDU.\n");
            itb = itb_dirty(itb, txg);
            if (!itb) {
                ret = -EAGAIN;
                goto out;
            }
            ite_update(hi, &itb->ite[ii->entry]);
        } else if (hi->flag & INDEX_UNLINK) {
            /* unlink */
            hvfs_debug(mds, "Find the ITE and unlink it.\n");
            itb = itb_dirty(itb, txg);
            if (!itb) {
                ret = -EAGAIN;
                goto out;
            }
            ite_unlink(&itb->ite[ii->entry], itb);
        } else if (hi->flag & INDEX_LINK_ADD) {
            /* hard link */
            hvfs_debug(mds, "Find the ITE and hard link it.\n");
            itb = itb_dirty(itb, txg);
            if (!itb) {
                ret = -EAGAIN;
                goto out;
            }
            itb->ite[ii->entry].s.mdu.nlink++;
            memcpy(data, &(itb->ite[ii->entry].g), HVFS_MDU_SIZE);
        } else if (hi->flag & INDEX_SYMLINK) {
            /* symlink */
            hvfs_err(mds, "Find the ITE and can NOT symlink it.\n");
            ret = -EEXIST;
            goto out;
        } else {
            hvfs_err(mds, "Hooo, what is your type: 0x%x\n", hi->flag);
            ret = -EINVAL;
            goto out;
        }
        ret = 0;
        goto out;
    }
    /* OK, can not find it, so ... */
    hvfs_debug(mds, "OK, the ITE do NOT exist in the ITB.\n");
    if (hi->flag & INDEX_CREATE || hi->flag & INDEX_SYMLINK) {
        hvfs_debug(mds, "Not find the ITE and create/symlink it.\n");
        itb_add_ite(itb, hi);
        ret = 0;
    } else {
        /* other operations means ENOENT */
        ret = -ENOENT;
    }
out:
    /* put the lock */
    if (hi->flag & INDEX_LOOKUP)
        itb_index_runlock(l);
    else
        itb_index_wunlock(l);
    return ret;
}
