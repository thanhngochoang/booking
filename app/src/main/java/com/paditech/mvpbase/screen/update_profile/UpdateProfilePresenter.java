package com.paditech.mvpbase.screen.update_profile;

import android.net.Uri;
import androidx.annotation.NonNull;

import com.google.android.gms.tasks.OnCompleteListener;
import com.google.android.gms.tasks.Task;
import com.google.firebase.firestore.FirebaseFirestore;
import com.google.firebase.storage.FirebaseStorage;
import com.google.firebase.storage.UploadTask;
import com.paditech.mvpbase.common.model.User;
import com.paditech.mvpbase.common.mvp.activity.ActivityPresenter;
import com.paditech.mvpbase.common.utils.PrefUtil;

import java.io.File;
import java.util.Map;

/**
 * Created by Fx570ex on 08-12-2017.
 */

public class UpdateProfilePresenter extends ActivityPresenter<UpdateProfileContact.ViewOps>
        implements UpdateProfileContact.PresenterViewOps {


    @Override
    public void savePhotographer(String imageFile, final User photographer) {
        try {
            getView().showProgressbar();
            if (imageFile == null) saveToFirestore(photographer);
            else {
                FirebaseStorage.getInstance()
                        .getReference().child("avatars").putFile(Uri.fromFile(new File(imageFile))).addOnCompleteListener(new OnCompleteListener<UploadTask.TaskSnapshot>() {
                    @Override
                    public void onComplete(@NonNull Task<UploadTask.TaskSnapshot> task) {
                        if (task.isSuccessful()) {
                            Uri downloadUrl = task.getResult().getDownloadUrl();
                            if (downloadUrl != null)
                                photographer.setAvatar(downloadUrl.toString());
                        }
                        saveToFirestore(photographer);
                    }
                });
            }
        } catch (Exception e) {
            e.printStackTrace();
            getView().hideProgressbar();
        }
    }

    private void saveToFirestore(final User photographer) {
        try {
            Map<String, Object> map = photographer.getMaps();
            FirebaseFirestore.getInstance().collection("users").document(photographer.getId()).set(photographer).addOnCompleteListener(new OnCompleteListener<Void>() {
                @Override
                public void onComplete(@NonNull Task<Void> task) {
                    getView().hideProgressbar();
                    if (task.isSuccessful()) {
                        PrefUtil.saveUser(getView().getActivityContext(), photographer);
                        getView().onSaveSuccess();
                    } else {
                        getView().onFailed(task.getException().getMessage());
                    }
                }
            });
        } catch (Exception e) {
            e.printStackTrace();
        }

    }
}
