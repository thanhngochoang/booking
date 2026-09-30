package com.paditech.mvpbase.screen.find_project;

import androidx.annotation.NonNull;
import android.util.Log;

import com.google.android.gms.tasks.OnCompleteListener;
import com.google.android.gms.tasks.Task;
import com.google.firebase.firestore.DocumentSnapshot;
import com.google.firebase.firestore.FirebaseFirestore;
import com.google.firebase.firestore.Query;
import com.google.firebase.firestore.QuerySnapshot;
import com.google.gson.Gson;
import com.paditech.mvpbase.common.model.BookStatus;
import com.paditech.mvpbase.common.model.Booking;
import com.paditech.mvpbase.common.mvp.fragment.FragmentPresenter;
import com.paditech.mvpbase.common.utils.PrefUtil;

import java.util.ArrayList;

/**
 * Created by Nha Nha on 1/3/2018.
 */

public class FindProjectPresenter extends FragmentPresenter<FindProjectContact.ViewOps> implements FindProjectContact.PresenterViewOps {
    @Override
    public void getListProjects() {
        try {
            getView().onLoading();
            FirebaseFirestore.getInstance().collection("booking").whereEqualTo("status", BookStatus.OPENED.getStatus())
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
                            if (!booking.getPhotographer_id().equals(PrefUtil.getUid())) {
                                bookings.add(booking);
                            }
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
