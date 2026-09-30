package com.paditech.mvpbase.screen.book;

import android.support.annotation.NonNull;

import com.google.android.gms.tasks.OnCompleteListener;
import com.google.android.gms.tasks.Task;
import com.google.firebase.firestore.FirebaseFirestore;
import com.google.firebase.firestore.QuerySnapshot;
import com.paditech.mvpbase.R;
import com.paditech.mvpbase.common.model.Album;
import com.paditech.mvpbase.common.model.BookStatus;
import com.paditech.mvpbase.common.model.Booking;
import com.paditech.mvpbase.common.mvp.fragment.FragmentPresenter;

/**
 * Created by ThanhNgocHoang on 12/7/2017.
 */

public class BookPresenter extends FragmentPresenter<BookContact.ViewOps> implements BookContact.PresenterViewOps {
    @Override
    public void getCover(String grapherId) {
        try {
            FirebaseFirestore.getInstance().collection("albums").whereEqualTo("photographer_id", grapherId).get().addOnCompleteListener(new OnCompleteListener<QuerySnapshot>() {
                @Override
                public void onComplete(@NonNull Task<QuerySnapshot> task) {
                    if (task.getResult() != null && task.getResult().getDocuments().size() > 0) {
                        Album album = task.getResult().getDocuments().get(0).toObject(Album.class);
                        if (album.getAlbum_files() != null && album.getAlbum_files().size() > 0)
                            getView().updateCover(album.getAlbum_files().get(0));
                    }
                }
            });
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    @Override
    public void onBook(Booking booking) {
        try {
            getView().showProgressbar();
            FirebaseFirestore.getInstance().collection("booking").document().set(booking.getMaps()).addOnCompleteListener(new OnCompleteListener<Void>() {
                @Override
                public void onComplete(@NonNull Task<Void> task) {
                    getView().hideProgressbar();
                    try {
                        if (task.isSuccessful()) {
                            getView().onBookSuccess();
                        } else {
                            if (task.getException() != null)
                                getView().showError(task.getException().getMessage());
                        }
                    } catch (Exception e) {
                        e.printStackTrace();
                    }

                }
            });
        } catch (Exception e) {
            e.printStackTrace();
            getView().hideProgressbar();
        }
    }

    @Override
    public void denyBooking(Booking booking) {
        try {
            getView().showProgressbar();
            FirebaseFirestore.getInstance().collection("booking").document(booking.getId()).update("status", BookStatus.DENIED.getStatus()).addOnCompleteListener(new OnCompleteListener<Void>() {
                @Override
                public void onComplete(@NonNull Task<Void> task) {
                    getView().hideProgressbar();
                    if (task.isSuccessful()) {
                        getView().onDeniedSuccess();
                    } else getView().onFailed(task.getException().getMessage());
                }
            });
        } catch (Exception e) {
            getView().hideProgressbar();
            e.printStackTrace();
        }
    }

    @Override
    public void acceptBooking(Booking booking) {
        try {
            getView().showProgressbar();
            FirebaseFirestore.getInstance().collection("booking").document(booking.getId()).update("status", BookStatus.ACCEPTED.getStatus()).addOnCompleteListener(new OnCompleteListener<Void>() {
                @Override
                public void onComplete(@NonNull Task<Void> task) {
                    getView().hideProgressbar();
                    if (task.isSuccessful()) {
                        getView().onAcceptedSuccess();
                    } else getView().onFailed(task.getException().getMessage());
                }
            });
        } catch (Exception e) {
            getView().hideProgressbar();
            e.printStackTrace();
        }
    }
}
