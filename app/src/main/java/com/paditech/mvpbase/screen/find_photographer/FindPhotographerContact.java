package com.paditech.mvpbase.screen.find_photographer;

import com.paditech.mvpbase.common.model.User;
import com.paditech.mvpbase.common.mvp.fragment.FragmentPresenterViewOps;
import com.paditech.mvpbase.common.mvp.fragment.FragmentViewOps;

import java.util.ArrayList;

/**
 * Created by ThanhNgocHoang on 11/15/2017.
 */

public interface FindPhotographerContact {
    interface ViewOps extends FragmentViewOps {
        void onSearchResults(ArrayList<User> photographers);
        void onLoading();
        void onLoadDone();
    }

    interface PresenterViewOps extends FragmentPresenterViewOps {
        void onSearchPhotographers(double lat, double lng, int rate);
    }
}
