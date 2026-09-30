package com.paditech.mvpbase.common.utils.get_image;

import android.app.Activity;

import com.paditech.mvpbase.common.mvp.activity.ActivityPresenterViewOps;
import com.paditech.mvpbase.common.mvp.activity.ActivityViewOps;

import java.util.ArrayList;

/**
 * Created by ThanhNgocHoang on 8/9/2017.
 */

public interface SelectMultiContact {
    interface ViewOps extends ActivityViewOps {
        void onUpdatePhotos(ArrayList<String> listPhotos);
    }

    interface PresenterViewOps extends ActivityPresenterViewOps {
        void getAllPhotos(Activity activity);
    }
}
