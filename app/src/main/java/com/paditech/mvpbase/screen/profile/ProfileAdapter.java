package com.paditech.mvpbase.screen.profile;

import androidx.recyclerview.widget.RecyclerView;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.ImageView;
import android.widget.RatingBar;
import android.widget.TextView;

import com.paditech.mvpbase.R;
import com.paditech.mvpbase.common.model.Comment;
import com.paditech.mvpbase.common.model.User;
import com.paditech.mvpbase.common.utils.ImageUtil;
import com.paditech.mvpbase.common.utils.PrefUtil;
import com.paditech.mvpbase.common.utils.StringUtil;

import java.util.ArrayList;

import butterknife.BindView;
import butterknife.ButterKnife;

/**
 * Created by ThanhNgocHoang on 11/15/2017.
 */

public class ProfileAdapter extends RecyclerView.Adapter<RecyclerView.ViewHolder> {
    private final int TYPE_PROFILE = 1;
    private final int TYPE_RATING = 2;

    private ArrayList<Comment> mListComments;
    private User mUser;

    public ProfileAdapter() {
        mListComments = new ArrayList<>();
    }

    public void setmUser(User mUser) {
        this.mUser = mUser;
        notifyDataSetChanged();
    }

    public void setmListComments(ArrayList<Comment> mListComments) {
        this.mListComments = mListComments;
        notifyDataSetChanged();
    }

    @Override
    public int getItemViewType(int position) {
        if (position == 0) return TYPE_PROFILE;
        return TYPE_RATING;
    }

    @Override
    public RecyclerView.ViewHolder onCreateViewHolder(ViewGroup parent, int viewType) {
        if (viewType == TYPE_PROFILE) {
            return new ProfileHolder(LayoutInflater.from(parent.getContext()).inflate(R.layout.item_about_profile, parent, false));
        }
        return new RatingHolder(LayoutInflater.from(parent.getContext()).inflate(R.layout.item_about_rating, parent, false));
    }

    @Override
    public void onBindViewHolder(RecyclerView.ViewHolder holder, int position) {
        int viewType = getItemViewType(position);
        if (viewType == TYPE_RATING) {
            RatingHolder ratingHolder = (RatingHolder) holder;
            ratingHolder.bindData(position);
        } else if (viewType == TYPE_PROFILE) {
            ProfileHolder profileHolder = (ProfileHolder) holder;
            profileHolder.bindData();
        }
    }

    @Override
    public int getItemCount() {
        if (mListComments != null)
            return mListComments.size() + 1;
        return 1;
    }

    protected class ProfileHolder extends RecyclerView.ViewHolder {
        @BindView(R.id.tv_name)
        TextView tvName;
        @BindView(R.id.tv_star)
        RatingBar tvStar;
        @BindView(R.id.tv_address)
        TextView tvAddress;
        @BindView(R.id.avatar)
        ImageView avatar;

        public ProfileHolder(View itemView) {
            super(itemView);
            ButterKnife.bind(this, itemView);
        }

        private void bindData() {
            User user = mUser;
            if (user != null) {
                ImageUtil.loadImage(itemView.getContext(), user.getAvatar(), avatar);
                tvAddress.setText(user.getAddress());
                tvName.setText(user.getFull_name());
                if (user.isIs_photographer()) {
                    tvStar.setVisibility(View.VISIBLE);
                    tvStar.setRating(4.6f);
                } else {
                    tvStar.setVisibility(View.GONE);
                }
            }
        }
    }

    protected class RatingHolder extends RecyclerView.ViewHolder {
        @BindView(R.id.tv_name)
        TextView tvName;
        @BindView(R.id.tv_star)
        RatingBar tvStar;
        @BindView(R.id.tv_comment)
        TextView tvComment;
        @BindView(R.id.tv_time)
        TextView tvTime;
        private RecyclerView.LayoutParams params;

        public RatingHolder(View itemView) {
            super(itemView);
            ButterKnife.bind(this, itemView);
            params = (RecyclerView.LayoutParams) itemView.getLayoutParams();
        }

        private void bindData(int pos) {
            try {
                Comment comment = mListComments.get(pos - 1);
                tvName.setText(comment.getUser_name());
                tvStar.setRating((float) comment.getRate());
                tvComment.setText(comment.getContent());
                tvTime.setText(StringUtil.getTimeCreated(itemView.getContext(), comment.getCreate_time()));
            } catch (Exception e) {
                e.printStackTrace();
            }

            if (pos == getItemCount() - 1) {
                params.bottomMargin = 300;
            } else {
                params.bottomMargin = 0;
            }
        }
    }
}
