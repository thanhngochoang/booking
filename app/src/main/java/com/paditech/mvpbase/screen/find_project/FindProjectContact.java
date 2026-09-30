package com.paditech.mvpbase.screen.find_project;

import com.paditech.mvpbase.common.model.Booking;
import com.paditech.mvpbase.common.mvp.fragment.FragmentPresenterViewOps;
import com.paditech.mvpbase.common.mvp.fragment.FragmentViewOps;

import java.util.ArrayList;

/**
 * Created by Nha Nha on 1/3/2018.
 */

public interface FindProjectContact {
    interface ViewOps extends FragmentViewOps {
        void updateProjects(ArrayList<Booking> projects);
    }

    interface PresenterViewOps extends FragmentPresenterViewOps {
        void getListProjects();
    }
}
