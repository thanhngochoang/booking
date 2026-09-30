package com.paditech.mvpbase.screen.main;

import com.paditech.mvpbase.common.mvp.activity.ActivityPresenterViewOps;
import com.paditech.mvpbase.common.mvp.activity.ActivityViewOps;

/**
 * Created by ThanhNgocHoang on 9/19/2017.
 */

public interface MainContact {
    interface ViewOps extends ActivityViewOps {

    }

    interface PresenterViewOps extends ActivityPresenterViewOps {
        int getBadgeCountMess();
        int getBadgeCountCalendar();
    }
}
