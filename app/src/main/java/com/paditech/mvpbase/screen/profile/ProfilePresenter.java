package com.paditech.mvpbase.screen.profile;

import com.google.firebase.database.DataSnapshot;
import com.google.firebase.database.DatabaseError;
import com.google.firebase.database.FirebaseDatabase;
import com.google.firebase.database.ValueEventListener;
import com.paditech.mvpbase.common.model.Comment;
import com.paditech.mvpbase.common.mvp.fragment.FragmentPresenter;

import java.util.ArrayList;

/**
 * Created by ThanhNgocHoang on 11/15/2017.
 */

public class ProfilePresenter extends FragmentPresenter<ProfileContact.ViewOps> implements ProfileContact.PresenterViewOps {
    @Override
    public void getListComments(String photographerId) {
        try {
            FirebaseDatabase.getInstance().getReference().child("comments").child(photographerId).addValueEventListener(new ValueEventListener() {
                @Override
                public void onDataChange(DataSnapshot dataSnapshot) {
                    if (getView() != null) {
                        if (dataSnapshot != null && dataSnapshot.getValue() != null) {
                            ArrayList<Comment> comments = new ArrayList<>();
                            for (DataSnapshot snapshot : dataSnapshot.getChildren()) {
                                Comment comment = snapshot.getValue(Comment.class);
                                comments.add(comment);
                            }
                            getView().updateListComments(comments);
                        } else getView().updateListComments(new ArrayList<Comment>());
                    }
                }

                @Override
                public void onCancelled(DatabaseError databaseError) {
                    if (getView() != null)
                        getView().updateListComments(new ArrayList<Comment>());
                }
            });
        } catch (Exception e) {
            e.printStackTrace();
        }
    }
}
