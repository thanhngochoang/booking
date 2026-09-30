package com.paditech.mvpbase.screen.my_project;

import androidx.recyclerview.widget.RecyclerView;
import android.view.View;
import android.view.ViewGroup;
import android.widget.FrameLayout;
import android.widget.ImageView;

import com.paditech.mvpbase.R;
import com.paditech.mvpbase.common.model.User;
import com.paditech.mvpbase.common.utils.ImageUtil;

import java.util.ArrayList;

import de.hdodenhof.circleimageview.CircleImageView;

/**
 * Created by Nha Nha on 1/3/2018.
 */

public class ListUserAdapter extends RecyclerView.Adapter<RecyclerView.ViewHolder> {
    private ArrayList<User> users;

    public void setUsers(ArrayList<User> users) {
        this.users = users;
        notifyDataSetChanged();
    }

    @Override
    public RecyclerView.ViewHolder onCreateViewHolder(ViewGroup parent, int viewType) {
        CircleImageView circleImageView = new CircleImageView(parent.getContext());
        int size = parent.getContext().getResources().getDimensionPixelSize(R.dimen.avatar_size_small);
        FrameLayout.LayoutParams layoutParams = new FrameLayout.LayoutParams(size, size);
        layoutParams.setMargins(20, 20, 20, 20);
        circleImageView.setLayoutParams(layoutParams);
        return new UserHolder(circleImageView);
    }

    @Override
    public void onBindViewHolder(RecyclerView.ViewHolder holder, int position) {
        ImageUtil.loadImage(holder.itemView.getContext(), users.get(position).getAvatar(), (ImageView) holder.itemView);
    }

    @Override
    public int getItemCount() {
        if (users != null) return users.size();
        return 0;
    }

    private class UserHolder extends RecyclerView.ViewHolder {

        public UserHolder(View itemView) {
            super(itemView);
        }
    }
}
