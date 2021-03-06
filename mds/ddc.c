/**
 * Copyright (c) 2009 Ma Can <ml.macana@gmail.com>
 *                           <macan@ncic.ac.cn>
 *
 * Armed with EMACS.
 * Time-stamp: <2011-05-05 09:40:03 macan>
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
#include "xnet.h"
#include "ring.h"
#include "mds.h"

int txg_ddc_send_request(struct dir_delta_au *dda)
{
    struct xnet_msg *msg;
    int err = 0;

    /* Step 1: prepare the xnet_msg */
    msg = xnet_alloc_msg(XNET_MSG_CACHE);
    if (!msg) {
        hvfs_err(mds, "xnet_alloc_msg() failed.\n");
        err = -ENOMEM;
        goto out;
    }

    /* Step 2: construct the xnet_msg to send it to the destination */
    xnet_msg_fill_tx(msg, XNET_MSG_REQ, 0,
                     hmo.site_id, dda->dd.site_id);
    xnet_msg_fill_cmd(msg, HVFS_MDS2MDS_AUDIRDELTA, dda->dd.duuid, 0);
#ifdef XNET_EAGER_WRITEV
    xnet_msg_add_sdata(msg, &msg->tx, sizeof(msg->tx));
#endif
    xnet_msg_add_sdata(msg, &dda->dd, sizeof(dda->dd));

    err = xnet_send(hmo.xc, msg);
    if (err) {
        hvfs_err(mds, "Request to AU dir delta the uuid %lx flag 0x%x nlink %d"
                 " failed w/ %d\n",
                 dda->dd.duuid, dda->dd.flag, 
                 atomic_read(&dda->dd.nlink), err);
        goto out_free_msg;
    }

    hvfs_err(mds, "Send AUDD uuid %lx nlink %d to site %lx salt %ld\n",
             dda->dd.duuid, atomic_read(&dda->dd.nlink), dda->dd.site_id,
             dda->dd.salt);
    /* We should got the reply to confirm and delete the dir delta au, but we
     * do not do this operation here. We us send w/o XNET_NEED_REPLY because
     * the reply maybe delievered very late. */
out_free_msg:
    xnet_free_msg(msg);
out:
    return err;
}

int txg_ddc_send_reply(struct hvfs_dir_delta *hdd)
{
    struct xnet_msg *msg;
    int err = 0;

    /* Step 1: prepare the xnet_msg */
    msg = xnet_alloc_msg(XNET_MSG_CACHE);
    if (!msg) {
        hvfs_err(mds, "xnet_alloc_msg() failed.\n");
        err = -ENOMEM;
        goto out;
    }

    /* Step 2: construct the xnet_msg to send it to the destination */
    xnet_msg_fill_tx(msg, XNET_MSG_REQ, 0,
                     hmo.site_id, hdd->site_id);
    xnet_msg_fill_cmd(msg, HVFS_MDS2MDS_AUDIRDELTA_R, hdd->duuid,
                      hdd->salt);
#ifdef XNET_EAGER_WRITEV
    xnet_msg_add_sdata(msg, &msg->tx, sizeof(msg->tx));
#endif
    xnet_msg_add_sdata(msg, hdd, sizeof(*hdd));

    err = xnet_send(hmo.xc, msg);
    if (err) {
        hvfs_err(mds, "Request to AU dir delta reply uuid %ld flag 0x%x "
                 "nlink %d failed w/ %d\n",
                 hdd->duuid, hdd->flag, 
                 atomic_read(&hdd->nlink), err);
        goto out_free_msg;
    }

    hvfs_warning(mds, "Send AUDD reply uuid %lx nlink %d to site %lx "
                 "salt %lx\n",
                 hdd->duuid, atomic_read(&hdd->nlink), hdd->site_id,
                 hdd->salt);
    /* We should not wait any reply :) */
out_free_msg:
    xnet_free_msg(msg);
out:
    return err;
}

/* txg_ddc_update_cbht()
 *
 * Update the cbht state based on the arguments
 */
int txg_ddc_update_cbht(struct dir_delta_au *dda)
{
    struct hvfs_index hi;
    struct mdu_update mu;
    struct timeval tv;
    struct hvfs_txg *txg;
    struct hvfs_md_reply *hmr;
    struct dhe *gdte;
    int err = 0;

    gdte = mds_dh_search(&hmo.dh, hmi.gdt_uuid);
    if (IS_ERR(gdte)) {
        /* fatal error */
        hvfs_err(mds, "This is a fatal error, we can not find the GDT DHE.\n");
        err = PTR_ERR(gdte);
        goto out;
    }

    hmr = get_hmr();
    if (!hmr) {
        mds_dh_put(gdte);
        hvfs_err(mds, "get_hmr() failed\n");
        err = -ENOMEM;
        goto out;
    }

    /* the target uuid is in the dda->dd.duuid, we use this uuid to update
     * the GDT's itb :) */
    memset(&hi, 0, sizeof(hi));
    hi.flag = INDEX_BY_UUID | INDEX_MDU_UPDATE;
    hi.uuid = dda->dd.duuid;
    hi.hash = hvfs_hash_gdt(hi.uuid, hmi.gdt_salt);
    hi.itbid = mds_get_itbid(gdte, hi.hash);
    mds_dh_put(gdte);
    hi.puuid = hmi.gdt_uuid;
    hi.psalt = hmi.gdt_salt;
    hi.data = &mu;

    memset(&mu, 0, sizeof(mu));
    if (dda->dd.flag & DIR_DELTA_NLINK) {
        mu.valid |= MU_NLINK_DELTA;
        mu.nlink = atomic_read(&dda->dd.nlink);
    }
    err = gettimeofday(&tv, NULL);
    if (err) {
        hvfs_err(mds, "gettimeofday() failed w/ %d", errno);
        /* if we cant get the time, we do not update the original timestamp of
         * the file */
        if (!mu.valid) {
            goto out_free;
        }
    } else {
        if (dda->dd.flag & DIR_DELTA_ATIME) {
            mu.valid |= MU_ATIME;
            mu.atime = tv.tv_sec;
        }
        if (dda->dd.flag & DIR_DELTA_MTIME) {
            mu.valid |= MU_MTIME;
            mu.mtime = tv.tv_sec;
        }
        if (dda->dd.flag & DIR_DELTA_CTIME) {
            mu.valid |= MU_CTIME;
            mu.ctime = tv.tv_sec;
        }
    }

    /* it is ok to update the CBHT state */
retry:
    txg = mds_get_open_txg(&hmo);
    err = mds_cbht_search(&hi, hmr, txg, &txg);
    txg_put(txg);

    if (err) {
        if (err == -EAGAIN || err == -ESPLIT ||
            err == -ERESTART) {
            /* have a breath */
            sched_yield();
            goto retry;
        } else if (err == -EHWAIT) {
            /* deep wait */
            sleep(1);
            goto retry;
        }
        hvfs_err(mds, "Error for AU update the dir delta %ld flag %x "
                 "nlink %d w/ %d\n",
                 hi.uuid, dda->dd.flag, 
                 atomic_read(&dda->dd.nlink), err);
    }

out_free:
    xfree(hmr);
out:
    return err;
}
