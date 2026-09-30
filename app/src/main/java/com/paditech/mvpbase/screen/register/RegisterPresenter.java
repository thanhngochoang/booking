package com.paditech.mvpbase.screen.register;

import androidx.annotation.NonNull;

import com.google.android.gms.tasks.OnCompleteListener;
import com.google.android.gms.tasks.Task;
import com.google.firebase.auth.AuthResult;
import com.google.firebase.auth.FirebaseAuth;
import com.google.firebase.auth.FirebaseUser;
import com.google.firebase.database.FirebaseDatabase;
import com.google.firebase.firestore.DocumentSnapshot;
import com.google.firebase.firestore.FirebaseFirestore;
import com.paditech.mvpbase.common.model.Device;
import com.paditech.mvpbase.common.model.User;
import com.paditech.mvpbase.common.mvp.activity.ActivityPresenter;
import com.paditech.mvpbase.common.utils.PrefUtil;

/**
 * Created by ThanhNgocHoang on 12/3/2017.
 */

public class RegisterPresenter extends ActivityPresenter<RegisterContact.ViewOps> implements RegisterContact.PresenterViewOps {

    @Override
    public void onRegister(String email, String password) {
        try {
            getView().showProgressbar();
            FirebaseAuth.getInstance().createUserWithEmailAndPassword(email, password).addOnCompleteListener(new OnCompleteListener<AuthResult>() {
                @Override
                public void onComplete(@NonNull Task<AuthResult> task) {
                    getView().hideProgressbar();
                    if (task.isSuccessful()) {
                        if (task.getResult().getUser() != null) {
                            FirebaseUser firebaseUser = task.getResult().getUser();
                            // bỏ phần này đi
                            User user = new User();
                            user.setId(firebaseUser.getUid());
                            user.setFull_name(firebaseUser.getDisplayName());
                            user.setMail_address(firebaseUser.getEmail());
                            if (firebaseUser.getPhotoUrl() != null)
                                user.setAvatar(firebaseUser.getPhotoUrl().toString());
                            PrefUtil.saveUser(getView().getActivityContext(), user);
                            FirebaseFirestore.getInstance().collection("users").document(user.getId()).set(user);
                            Device device = new Device(getView().getActivityContext());
                            FirebaseDatabase.getInstance().getReference().child("user_devices").child(user.getId()).setValue(device);
                            getView().onRegisterSuccess();
                        }
                    } else {
                        if (task.getException() != null) {
                            getView().onFailed(task.getException().getMessage());
                        }
                    }
                }
            });
        } catch (Exception e) {
            e.printStackTrace();
            getView().hideProgressbar();
        }
    }

}
