package com.paditech.mvpbase.screen.create_project;

import com.paditech.mvpbase.common.model.Booking;
import com.paditech.mvpbase.common.mvp.fragment.FragmentPresenterViewOps;
import com.paditech.mvpbase.common.mvp.fragment.FragmentViewOps;

/**
 * Created by Nha Nha on 1/3/2018.
 */

public interface CreateProjectContact {
    interface ViewOps extends FragmentViewOps {
        void onSuccess();
    }

    interface PresenterViewOps extends FragmentPresenterViewOps {
        void createProject(Booking booking);
        void onCloseProject(Booking booking);
        void onJoinProject(Booking booking);
    }
}
