package com.paditech.mvpbase.screen.home;

import com.paditech.mvpbase.common.model.Album;
import com.paditech.mvpbase.common.mvp.activity.ActivityPresenterViewOps;
import com.paditech.mvpbase.common.mvp.activity.ActivityViewOps;
import com.paditech.mvpbase.common.mvp.fragment.FragmentPresenterViewOps;
import com.paditech.mvpbase.common.mvp.fragment.FragmentViewOps;

import java.util.ArrayList;

/**
 * Created by ThanhNgocHoang on 11/4/2017.
 */

public interface HomeContact {
    interface ViewOps extends FragmentViewOps {
        void setList(ArrayList<Album> list);
    }

    interface PresenterViewOps extends FragmentPresenterViewOps {
        void getListData();
    }
}
