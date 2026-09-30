package com.paditech.mvpbase.screen.book;

import com.paditech.mvpbase.common.model.Booking;
import com.paditech.mvpbase.common.mvp.fragment.FragmentPresenterViewOps;
import com.paditech.mvpbase.common.mvp.fragment.FragmentViewOps;

/**
 * Created by ThanhNgocHoang on 12/7/2017.
 */

public interface BookContact {
    interface ViewOps extends FragmentViewOps {
        void updateCover(String coverUrl);
        void onBookSuccess();
        void onDeniedSuccess();
        void onAcceptedSuccess();
        void onFailed(String message);
    }

    interface PresenterViewOps extends FragmentPresenterViewOps {
        void getCover(String grapherId);
        void onBook(Booking booking);
        void denyBooking(Booking booking);
        void acceptBooking(Booking booking);
    }
}
