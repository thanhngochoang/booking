package com.paditech.mvpbase.screen.calendar;

import com.alamkanak.weekview.WeekViewEvent;
import com.paditech.mvpbase.common.model.Booking;
import com.paditech.mvpbase.common.mvp.fragment.FragmentPresenterViewOps;
import com.paditech.mvpbase.common.mvp.fragment.FragmentViewOps;

import java.util.ArrayList;
import java.util.List;

/**
 * Created by ThanhNgocHoang on 12/25/2017.
 */

public interface CalendarContact {
    interface ViewOps extends FragmentViewOps {
        void updateListEvents(List<Booking> bookings);
    }

    interface PresenterViewOps extends FragmentPresenterViewOps {
        ArrayList<WeekViewEvent> getListEvents(int year, int month);
    }
}
