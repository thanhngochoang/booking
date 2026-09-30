package com.paditech.mvpbase.screen.create_project;

import android.support.annotation.NonNull;

import com.google.android.gms.tasks.OnCompleteListener;
import com.google.android.gms.tasks.Task;
import com.google.firebase.firestore.FirebaseFirestore;
import com.paditech.mvpbase.R;
import com.paditech.mvpbase.common.model.BookStatus;
import com.paditech.mvpbase.common.model.Booking;
import com.paditech.mvpbase.common.mvp.fragment.FragmentPresenter;
import com.paditech.mvpbase.common.utils.PrefUtil;

/**
 * Created by Nha Nha on 1/3/2018.
 */

public class CreateProjectPresenter extends FragmentPresenter<CreateProjectContact.ViewOps> implements CreateProjectContact.PresenterViewOps {
    @Override
    public void createProject(Booking booking) {
        try {
            getView().showProgressbar();
            FirebaseFirestore.getInstance().collection("booking").document().set(booking.getMaps()).addOnCompleteListener(new OnCompleteListener<Void>() {
                @Override
                public void onComplete(@NonNull Task<Void> task) {
                    getView().hideProgressbar();
                    try {
                        if (task.isSuccessful()) {
                            getView().showToast(getView().getActivityContext().getString(R.string.create_project_success));
                            getView().onSuccess();
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
    public void onCloseProject(Booking booking) {
        try {
            getView().showProgressbar();
            FirebaseFirestore.getInstance().collection("booking").document(booking.getId()).update("status", BookStatus.CLOSED.getStatus()).addOnCompleteListener(new OnCompleteListener<Void>() {
                @Override
                public void onComplete(@NonNull Task<Void> task) {
                    getView().hideProgressbar();
                    if (task.isSuccessful()) {
                        getView().showToast("Bạn đã đóng project này!");
                        getView().onSuccess();
                    } else getView().showError(task.getException().getMessage());
                }
            });
        } catch (Exception e) {
            getView().hideProgressbar();
            e.printStackTrace();
        }
    }

    @Override
    public void onJoinProject(Booking booking) {
        try {
            getView().showProgressbar();
            FirebaseFirestore.getInstance().collection("booking").document(booking.getId())
                    .collection("photographers_attended").document(PrefUtil.getUid())
                    .set(PrefUtil.getUser(getView().getActivityContext())).addOnCompleteListener(new OnCompleteListener<Void>() {
                @Override
                public void onComplete(@NonNull Task<Void> task) {
                    getView().hideProgressbar();
                    if (task.isSuccessful()) {
                        getView().showToast("Bạn đã tham gia Project thành công!!");
                        getView().onSuccess();
                    } else getView().showError(task.getException().getMessage());
                }
            });
        } catch (Exception e) {
            getView().hideProgressbar();
            e.printStackTrace();
        }
    }
}
