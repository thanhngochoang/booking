package com.paditech.mvpbase.screen.login;

import android.content.Intent;

import com.paditech.mvpbase.common.mvp.activity.ActivityPresenterViewOps;
import com.paditech.mvpbase.common.mvp.activity.ActivityViewOps;

/**
 * Created by ThanhNgocHoang on 11/22/2017.
 */

public interface LoginContact {
    interface ViewOps extends ActivityViewOps {
        void goToHome();
        void onFailed(String message);
        void goTermView();
    }

    interface PresenterViewOps extends ActivityPresenterViewOps {
        void onFbSignIn(int type);

        void onGgSignIn(int type);

        void onLoginNormal(String email, String password);

        void onActivityResult(int requestCode, int resultCode, Intent data);
    }
}
