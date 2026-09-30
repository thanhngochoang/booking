package com.paditech.mvpbase.screen.update_profile;

import com.paditech.mvpbase.common.model.User;
import com.paditech.mvpbase.common.mvp.activity.ActivityPresenterViewOps;
import com.paditech.mvpbase.common.mvp.activity.ActivityViewOps;

/**
 * Created by Fx570ex on 08-12-2017.
 */

public class UpdateProfileContact {
    interface ViewOps extends ActivityViewOps {
        void onSaveSuccess();
        void onFailed(String message);
    }

    interface PresenterViewOps extends ActivityPresenterViewOps {
        void savePhotographer(String avatarFile, User photographer);
    }
}
