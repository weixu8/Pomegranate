/**
 * Copyright (c) 2009 Ma Can <ml.macana@gmail.com>
 *                           <macan@ncic.ac.cn>
 *
 * Armed with EMACS.
 * Time-stamp: <2012-08-13 09:47:10 macan>
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
#include "root.h"

void root_handle_err(struct xnet_msg *msg, int err)
{
}

/* root_dispatch()
 *
 * The first dispatcher of R2
 */
int root_dispatch(struct xnet_msg *msg)
{
    int err = 0;

    switch (msg->tx.cmd) {
    case HVFS_R2_REG:
        err = root_do_reg(msg);
        break;
    case HVFS_R2_UNREG:
        err = root_do_unreg(msg);
        break;
    case HVFS_R2_UPDATE:
        err = root_do_update(msg);
        break;
    case HVFS_R2_MKFS:
        err = root_do_mkfs(msg);
        break;
    case HVFS_R2_HB:
        err = root_do_hb(msg);
        break;
    case HVFS_MDS2MDS_AUBITMAP:
        err = root_do_bitmap(msg);
        break;
    case HVFS_R2_LGDT:
        err = root_do_lgdt(msg);
        break;
    case HVFS_R2_LBGDT:
        err = root_do_lbgdt(msg);
        break;
    case HVFS_R2_ONLINE:
        err = root_do_online(msg);
        break;
    case HVFS_R2_OFFLINE:
        err = root_do_offline(msg);
        break;
    case HVFS_R2_FTREPORT:
        err = root_do_ftreport(msg);
        break;
    case HVFS_R2_ADDSITE:
        err = root_do_addsite(msg);
        break;
    case HVFS_R2_RMVSITE:
        err = root_do_rmvsite(msg);
        break;
    case HVFS_R2_SHUTDOWN:
        err = root_do_shutdown(msg);
        break;
    case HVFS_R2_PROFILE:
        err = root_do_profile(msg);
        break;
    case HVFS_R2_INFO:
        err = root_do_info(msg);
        break;
    case HVFS_R2_OREP:
        err = root_do_objrep(msg);
        break;
    case HVFS_OSD_QUERY:
        err = root_do_query_obj(msg);
        break;
    default:
        hvfs_err(root, "R2 core dispatcher handle INVALID "
                 "request <0x%lx %d>\n",
                 msg->tx.ssite_id, msg->tx.reqno);
    }
    
    root_handle_err(msg, err);
    return err;
}

