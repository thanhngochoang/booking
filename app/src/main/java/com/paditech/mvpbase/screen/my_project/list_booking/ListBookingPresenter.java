package com.paditech.mvpbase.screen.my_project.list_booking;

import android.support.annotation.NonNull;

import com.google.android.gms.tasks.OnCompleteListener;
import com.google.android.gms.tasks.Task;
import com.google.firebase.firestore.DocumentSnapshot;
import com.google.firebase.firestore.FirebaseFirestore;
import com.google.firebase.firestore.Query;
import com.google.firebase.firestore.QuerySnapshot;
import com.paditech.mvpbase.common.model.Booking;
import com.paditech.mvpbase.common.mvp.fragment.FragmentPresenter;
import com.paditech.mvpbase.common.utils.PrefUtil;

import java.util.ArrayList;

/**
 * Created by Nha Nha on 1/3/2018.
 */

public class ListBookingPresenter extends FragmentPresenter<ListBookingContact.ViewOps> implements ListBookingContact.PresenterViewOps {


    @Override
    public void getBookingHistory() {
        try {
            getView().onLoading();
            FirebaseFirestore.getInstance().collection("booking").whereEqualTo("user_id", PrefUtil.getUid())
                    .orderBy("create_time", Query.Direction.DESCENDING).get().addOnCompleteListener(new OnCompleteListener<QuerySnapshot>() {
                @Override
                public void onComplete(@NonNull Task<QuerySnapshot> task) {
                    getView().onLoadDone();
                    if (task.isSuccessful()) {
                        ArrayList<Booking> bookings = new ArrayList<>();
                        for (DocumentSnapshot documentSnapshot : task.getResult().getDocuments()) {
                            Booking booking = documentSnapshot.toObject(Booking.class);
                            booking.setHasAttends(documentSnapshot.getData().containsKey("photographers_attended"));
                            booking.setId(documentSnapshot.getId());
                            bookings.add(booking);
                        }
                        getView().updateBookingList(bookings);
                    }
                }
            });
        } catch (Exception e) {
            e.printStackTrace();
            getView().onLoadDone();
        }
    }

    @Override
    public void getListProjects() {
        try {
            getView().onLoading();
            FirebaseFirestore.getInstance().collection("booking").whereEqualTo("photographer_id", PrefUtil.getUid())
                    .orderBy("create_time", Query.Direction.DESCENDING).get().addOnCompleteListener(new OnCompleteListener<QuerySnapshot>() {
                @Override
                public void onComplete(@NonNull Task<QuerySnapshot> task) {
                    getView().onLoadDone();
                    if (task.isSuccessful()) {
                        ArrayList<Booking> bookings = new ArrayList<>();
                        for (DocumentSnapshot documentSnapshot : task.getResult().getDocuments()) {
                            Booking booking = documentSnapshot.toObject(Booking.class);
                            booking.setHasAttends(documentSnapshot.getData().containsKey("photographers_attended"));
                            booking.setId(documentSnapshot.getId());
                            bookings.add(booking);
                        }
                        getView().updateProjects(bookings);
                    }
                }
            });
        } catch (Exception e) {
            e.printStackTrace();
            getView().onLoadDone();
        }
    }
}
