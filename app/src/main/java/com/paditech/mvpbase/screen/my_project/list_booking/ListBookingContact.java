package com.paditech.mvpbase.screen.my_project.list_booking;

import com.paditech.mvpbase.common.model.Booking;
import com.paditech.mvpbase.common.mvp.fragment.FragmentPresenterViewOps;
import com.paditech.mvpbase.common.mvp.fragment.FragmentViewOps;

import java.util.ArrayList;

/**
 * Created by Nha Nha on 1/3/2018.
 */

public interface ListBookingContact {
    interface ViewOps extends FragmentViewOps {
        void updateBookingList(ArrayList<Booking> bookings);
        void updateProjects(ArrayList<Booking> projects);
    }

    interface PresenterViewOps extends FragmentPresenterViewOps {
        void getBookingHistory();
        void getListProjects();
    }
}
