package com.paditech.mvpbase.screen.messenger;

import android.support.v7.widget.LinearLayoutManager;
import android.support.v7.widget.RecyclerView;
import android.view.KeyEvent;
import android.view.MotionEvent;
import android.view.View;
import android.view.inputmethod.EditorInfo;
import android.widget.EditText;
import android.widget.TextView;

import com.paditech.mvpbase.R;
import com.paditech.mvpbase.common.firebase.FirebaseHelper;
import com.paditech.mvpbase.common.firebase.GetUserInfoListener;
import com.paditech.mvpbase.common.model.ChatRoom;
import com.paditech.mvpbase.common.model.Message;
import com.paditech.mvpbase.common.model.User;
import com.paditech.mvpbase.common.mvp.fragment.FragmentPresenter;
import com.paditech.mvpbase.common.mvp.fragment.MVPFragment;
import com.paditech.mvpbase.common.utils.CommonUtil;

import butterknife.BindView;
import butterknife.OnClick;

/**
 * Created by ThanhNgocHoang on 11/15/2017.
 */

public class MessengerFragment extends MVPFragment<MessengerContact.PresenterViewOps> implements MessengerContact.ViewOps {

    @BindView(R.id.recycler_view)
    RecyclerView recyclerView;
    @BindView(R.id.et_message)
    EditText etMessage;
    @BindView(R.id.btn_send)
    View btnSend;

    private MessageAdapter mMessageAdapter;
    private User mPhotographer;
    private ChatRoom mChatRoom;

    public static MessengerFragment newInstance(User photographer) {
        MessengerFragment messengerFragment = new MessengerFragment();
        messengerFragment.mPhotographer = photographer;
        return messengerFragment;
    }

    public static MessengerFragment newInstance(ChatRoom chatRoom) {
        MessengerFragment messengerFragment = new MessengerFragment();
        messengerFragment.mChatRoom = chatRoom;
        return messengerFragment;
    }

    @Override
    protected int getContentView() {
        return R.layout.frag_chating;
    }

    @Override
    protected void initView(View view) {
        setupRecyclerView();
    }

    @Override
    protected String getTitle() {
        return getString(R.string.message);
    }

    private void setupRecyclerView() {
        mMessageAdapter = new MessageAdapter();
        recyclerView.setLayoutManager(new LinearLayoutManager(getActivityContext(), LinearLayoutManager.VERTICAL, true));
        recyclerView.setAdapter(mMessageAdapter);
        if (mPhotographer != null) {
            getPresenter().setPhotographer(mPhotographer.getId());
            mMessageAdapter.setData(mPhotographer.getAvatar());
        } else {
            getPresenter().setChatRoom(mChatRoom);
            FirebaseHelper.getUserInfo(mChatRoom.getTargetId(), new GetUserInfoListener() {
                @Override
                public void getUserInfo(User user) {
                    mMessageAdapter.setData(user.getAvatar());
                }
            });
        }
        etMessage.setOnEditorActionListener(new TextView.OnEditorActionListener() {
            @Override
            public boolean onEditorAction(TextView v, int actionId, KeyEvent event) {
                if (actionId == EditorInfo.IME_ACTION_SEND || actionId == EditorInfo.IME_ACTION_DONE || actionId == EditorInfo.IME_ACTION_NEXT) {
                    sendMessage();
                    return true;
                }
                return false;
            }
        });
        btnSend.setOnTouchListener(new View.OnTouchListener() {
            @Override
            public boolean onTouch(View v, MotionEvent event) {
                return false;
            }
        });

        getPresenter().getMessage();
    }

    private void sendMessage() {
        getPresenter().sendMessage(etMessage.getText().toString().trim());
        if (CommonUtil.hasConnected(getActivityContext())) etMessage.setText("");
    }

    @Override
    protected Class<? extends FragmentPresenter> onRegisterPresenter() {
        return MessengerPresenter.class;
    }

    @OnClick(R.id.btn_photo)
    public void onViewClicked() {
    }

    @OnClick(R.id.btn_send)
    public void sendMessageClick() {
        sendMessage();
    }

    @Override
    public void addMessage(Message message) {
        mMessageAdapter.addMessage(message);
        recyclerView.smoothScrollToPosition(0);
    }

    @Override
    public void onDestroy() {
        super.onDestroy();
        getPresenter().setRead();
    }
}
