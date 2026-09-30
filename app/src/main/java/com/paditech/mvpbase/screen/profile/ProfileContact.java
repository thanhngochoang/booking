package com.paditech.mvpbase.screen.profile;

import com.paditech.mvpbase.common.model.Comment;
import com.paditech.mvpbase.common.mvp.fragment.FragmentPresenterViewOps;
import com.paditech.mvpbase.common.mvp.fragment.FragmentViewOps;

import java.util.ArrayList;

/**
 * Created by ThanhNgocHoang on 11/15/2017.
 */

public interface ProfileContact {
    interface ViewOps extends FragmentViewOps {
        void updateListComments(ArrayList<Comment> comments);
    }

    interface PresenterViewOps extends FragmentPresenterViewOps {
        void getListComments(String photographerId);
    }
}
