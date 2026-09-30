package com.paditech.mvpbase.screen.list_messenger;

import android.support.v7.widget.RecyclerView;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.TextView;

import com.paditech.mvpbase.R;
import com.paditech.mvpbase.common.firebase.FirebaseHelper;
import com.paditech.mvpbase.common.firebase.GetTimeAndMessageChatRoomListener;
import com.paditech.mvpbase.common.firebase.GetUserInfoListener;
import com.paditech.mvpbase.common.model.ChatRoom;
import com.paditech.mvpbase.common.model.User;
import com.paditech.mvpbase.common.utils.ImageUtil;
import com.paditech.mvpbase.common.utils.StringUtil;

import java.util.ArrayList;

import butterknife.BindView;
import butterknife.ButterKnife;
import de.hdodenhof.circleimageview.CircleImageView;

/**
 * Created by ThanhNgocHoang on 12/17/2017.
 */

public class ListMessengerAdapter extends RecyclerView.Adapter<RecyclerView.ViewHolder> {

    private ArrayList<ChatRoom> mChatRooms;
    private OnGoChatRoomListener mOnGoChatRoomListener;

    public ListMessengerAdapter() {
        mChatRooms = new ArrayList<>();
    }

    public void setmChatRooms(ArrayList<ChatRoom> mChatRooms) {
        this.mChatRooms = mChatRooms;
        notifyDataSetChanged();
    }

    public void setmOnGoChatRoomListener(OnGoChatRoomListener mOnGoChatRoomListener) {
        this.mOnGoChatRoomListener = mOnGoChatRoomListener;
    }

    @Override
    public RecyclerView.ViewHolder onCreateViewHolder(ViewGroup parent, int viewType) {
        return new RoomHolder(LayoutInflater.from(parent.getContext()).inflate(R.layout.item_chat_room, parent, false));
    }

    @Override
    public void onBindViewHolder(RecyclerView.ViewHolder holder, int position) {
        RoomHolder roomHolder = (RoomHolder) holder;
        roomHolder.bindData(position);

    }

    @Override
    public int getItemCount() {
        if (mChatRooms != null) return mChatRooms.size();
        return 0;
    }

    protected class RoomHolder extends RecyclerView.ViewHolder {
        @BindView(R.id.avatar)
        CircleImageView avatar;
        @BindView(R.id.tv_name)
        TextView tvName;
        @BindView(R.id.tv_message)
        TextView tvMessage;
        @BindView(R.id.tv_time)
        TextView tvTime;
        @BindView(R.id.badge)
        View badge;

        public RoomHolder(View itemView) {
            super(itemView);
            ButterKnife.bind(this, itemView);
        }

        private void bindData(final int pos) {
            try {
                final ChatRoom chatRoom = mChatRooms.get(pos);
                if(chatRoom.isIs_read()) badge.setVisibility(View.GONE);
                else badge.setVisibility(View.VISIBLE);
                if (chatRoom.getRoom_avatar() == null && chatRoom.getRoom_name() == null) {
                    String targetId = chatRoom.getTargetId();
                    if (targetId != null) {
                        FirebaseHelper.getUserInfo(targetId, new GetUserInfoListener() {
                            @Override
                            public void getUserInfo(User user) {
                                if (user != null) {
                                    try {
                                        chatRoom.setRoom_avatar(user.getAvatar());
                                        chatRoom.setRoom_name(user.getFull_name());
                                        mChatRooms.set(pos, chatRoom);
                                        notifyDataSetChanged();
                                    } catch (Exception e) {
                                        e.printStackTrace();
                                    }
                                }
                            }
                        });
                    }
                } else {
                    tvName.setText(chatRoom.getRoom_name());
                    ImageUtil.loadImage(itemView.getContext(), chatRoom.getRoom_avatar(), avatar, R.color.white, R.color.white);
                }
                if (chatRoom.getLastMessage() == null && chatRoom.getLastTime() <= 0) {
                    FirebaseHelper.getTimeAndMessageChatRoom(chatRoom.getId(), new GetTimeAndMessageChatRoomListener() {
                        @Override
                        public void onGetData(String lastMessage, long last_time) {
                            try {
                                chatRoom.setLastMessage(lastMessage);
                                chatRoom.setLastTime(last_time);
                                mChatRooms.set(pos, chatRoom);
                                notifyDataSetChanged();
                            } catch (Exception e) {
                                e.printStackTrace();
                            }
                        }
                    });
                } else {
                    tvMessage.setText(chatRoom.getLastMessage());
                    tvTime.setText(StringUtil.getTimeCreated(itemView.getContext(), chatRoom.getLastTime()));
                }
                itemView.setOnClickListener(new View.OnClickListener() {
                    @Override
                    public void onClick(View v) {
                        if (mOnGoChatRoomListener != null)
                            mOnGoChatRoomListener.goChatRoom(chatRoom);
                    }
                });
            } catch (Exception e) {
                e.printStackTrace();
            }

        }
    }

    public interface OnGoChatRoomListener {
        void goChatRoom(ChatRoom chatRoom);
    }
}
