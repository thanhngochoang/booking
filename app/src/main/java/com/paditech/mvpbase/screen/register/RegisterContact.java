package com.paditech.mvpbase.screen.register;

import com.paditech.mvpbase.common.mvp.activity.ActivityPresenterViewOps;
import com.paditech.mvpbase.common.mvp.activity.ActivityViewOps;

/**
 * Created by ThanhNgocHoang on 12/3/2017.
 */

public interface RegisterContact {
    interface ViewOps extends ActivityViewOps {
        void onRegisterSuccess();
        void onFailed(String message);

    }

    interface PresenterViewOps extends ActivityPresenterViewOps {
        void onRegister(String email, String password);
    }
}
