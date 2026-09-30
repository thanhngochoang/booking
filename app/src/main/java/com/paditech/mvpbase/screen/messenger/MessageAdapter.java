package com.paditech.mvpbase.screen.messenger;

import android.support.v7.widget.RecyclerView;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.ImageView;
import android.widget.TextView;

import com.paditech.mvpbase.R;
import com.paditech.mvpbase.common.model.Message;
import com.paditech.mvpbase.common.utils.ImageUtil;
import com.paditech.mvpbase.common.utils.PrefUtil;
import com.paditech.mvpbase.common.utils.StringUtil;

import java.util.ArrayList;
import java.util.Collections;

import butterknife.BindView;
import butterknife.ButterKnife;

/**
 * Created by NhaPCS on 09/04/2017.
 */

public class MessageAdapter extends RecyclerView.Adapter<RecyclerView.ViewHolder> {
    private final int TYPE_ME = 1;
    private final int TYPE_YOU = 2;

    private ArrayList<Message> mListMessage;
    private String mAvatarURL;

    public MessageAdapter() {
        this.mListMessage = new ArrayList<>();
    }

    public void setData(String avatar) {
        this.mAvatarURL = avatar;
        notifyDataSetChanged();
    }

    public void setListMessage(ArrayList<Message> messages) {
        mListMessage = messages;
        Collections.reverse(mListMessage);
        notifyDataSetChanged();
    }

    public void addMessage(Message message) {
        mListMessage.add(0, message);
        notifyDataSetChanged();
    }

    @Override
    public int getItemViewType(int position) {
        if (mListMessage.get(position).owner.equals(PrefUtil.getUid()))
            return TYPE_ME;
        else return TYPE_YOU;
    }

    @Override
    public RecyclerView.ViewHolder onCreateViewHolder(ViewGroup parent, int viewType) {
        if (viewType == TYPE_ME) {
            View view = LayoutInflater.from(parent.getContext()).inflate(R.layout.item_chat_me, parent, false);
            return new ChatMeHolder(view);
        } else if (viewType == TYPE_YOU) {
            View view = LayoutInflater.from(parent.getContext()).inflate(R.layout.item_chat_you, parent, false);
            return new ChatYouHolder(view);
        }
        return null;
    }

    @Override
    public void onBindViewHolder(RecyclerView.ViewHolder holder, int position) {
        int viewType = getItemViewType(position);
        if (viewType == TYPE_YOU) {
            ChatYouHolder youHolder = (ChatYouHolder) holder;
            youHolder.bindHolder(position);
        } else if (viewType == TYPE_ME) {
            ChatMeHolder meHolder = (ChatMeHolder) holder;
            meHolder.bindHolder(position);
        }
    }

    @Override
    public int getItemCount() {
        return mListMessage.size();
    }

    public class ChatMeHolder extends RecyclerView.ViewHolder {
        @BindView(R.id.tv_content)
        TextView mTvContent;
        @BindView(R.id.tv_time)
        TextView mTvTime;
        @BindView(R.id.icon)
        View mRear;
        @BindView(R.id.image)
        ImageView mImage;

        public ChatMeHolder(View itemView) {
            super(itemView);
            ButterKnife.bind(this, itemView);
        }

        public void bindHolder(int pos) {
            try {
                itemView.setVisibility(View.VISIBLE);
                Message message = mListMessage.get(pos);
                if (message == null) return;
                if (StringUtil.isEmpty(message.content)) {
                    mTvContent.setVisibility(View.GONE);
                    mImage.setVisibility(View.VISIBLE);
                    ImageUtil.loadImage(itemView.getContext(), message.image, mImage);
                } else {
                    mTvContent.setVisibility(View.VISIBLE);
                    mTvContent.setText(message.content);
                    mImage.setVisibility(View.GONE);

                }
                mTvTime.setText(message.getTime());
                if (pos > 0) {
                    if (mListMessage.get(pos - 1).owner.equals(message.owner)) {
                        mRear.setVisibility(View.INVISIBLE);
                    } else mRear.setVisibility(View.VISIBLE);
                } else {
                    mRear.setVisibility(View.VISIBLE);
                }
            } catch (Exception e) {
                itemView.setVisibility(View.GONE);
                e.printStackTrace();
            }

        }
    }

    public class ChatYouHolder extends RecyclerView.ViewHolder {
        @BindView(R.id.tv_content)
        TextView mTvContent;

        @BindView(R.id.tv_time)
        TextView mTvTime;

        @BindView(R.id.icon)
        View mRear;

        @BindView(R.id.avatar)
        ImageView mAvatar;

        @BindView(R.id.image)
        ImageView mImage;

        public ChatYouHolder(View itemView) {
            super(itemView);
            ButterKnife.bind(this, itemView);
        }

        public void bindHolder(int pos) {
            try {
                itemView.setVisibility(View.VISIBLE);
                Message message = mListMessage.get(pos);
                if (message == null) return;
                if (StringUtil.isEmpty(message.content)) {
                    mTvContent.setVisibility(View.GONE);
                    mImage.setVisibility(View.VISIBLE);
                    ImageUtil.loadImage(itemView.getContext(), message.image, mImage);
                } else {
                    mTvContent.setVisibility(View.VISIBLE);
                    mImage.setVisibility(View.GONE);
                    mTvContent.setText(message.content);
                }
                mTvTime.setText(message.getTime());
                if (pos > 0) {
                    if (mListMessage.get(pos - 1).owner.equals(message.owner)) {
                        mRear.setVisibility(View.INVISIBLE);
                        mAvatar.setVisibility(View.GONE);
                    } else {
                        mRear.setVisibility(View.VISIBLE);
                        mAvatar.setVisibility(View.VISIBLE);
                        ImageUtil.loadImage(itemView.getContext(), mAvatarURL, mAvatar);
                    }
                } else {
                    mAvatar.setVisibility(View.VISIBLE);
                    ImageUtil.loadImage(itemView.getContext(), mAvatarURL, mAvatar);
                    mRear.setVisibility(View.VISIBLE);
                }
            } catch (Exception e) {
                itemView.setVisibility(View.GONE);
                e.printStackTrace();
            }
        }
    }
}
