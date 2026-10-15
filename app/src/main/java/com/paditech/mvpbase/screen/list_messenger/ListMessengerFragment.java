package com.paditech.mvpbase.screen.list_messenger;

import android.os.Bundle;
import androidx.annotation.Nullable;
import androidx.swiperefreshlayout.widget.SwipeRefreshLayout;
import androidx.recyclerview.widget.LinearLayoutManager;
import androidx.recyclerview.widget.RecyclerView;
import android.view.View;

import com.paditech.mvpbase.R;
import com.paditech.mvpbase.common.event.OnUpdateMessagesEvent;
import com.paditech.mvpbase.common.model.ChatRoom;
import com.paditech.mvpbase.common.mvp.fragment.FragmentPresenter;
import com.paditech.mvpbase.common.mvp.fragment.MVPFragment;
import com.paditech.mvpbase.screen.messenger.MessengerFragment;

import org.greenrobot.eventbus.EventBus;
import org.greenrobot.eventbus.Subscribe;
import org.greenrobot.eventbus.ThreadMode;

import java.util.ArrayList;

import butterknife.BindView;

/**
 * Created by ThanhNgocHoang on 12/16/2017.
 */

public class ListMessengerFragment extends MVPFragment<ListMessengerContact.PresenterViewOps>
        implements ListMessengerContact.ViewOps, ListMessengerAdapter.OnGoChatRoomListener {
    @BindView(R.id.recycler_view)
    RecyclerView recyclerView;
    @BindView(R.id.swipe_refresh_layout)
    SwipeRefreshLayout swipeRefreshLayout;

    private ListMessengerAdapter mListMessengerAdapter;

    @Override
    protected int getContentView() {
        return R.layout.frag_list;
    }

    @Override
    public void onCreate(@Nullable Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        EventBus.getDefault().register(this);
    }

    @Override
    public void onDestroy() {
        EventBus.getDefault().unregister(this);
        super.onDestroy();
    }

    @Override
    protected void initView(View view) {
        mListMessengerAdapter = new ListMessengerAdapter();
        mListMessengerAdapter.setmOnGoChatRoomListener(this);
        recyclerView.setLayoutManager(new LinearLayoutManager(getActivityContext()));
        recyclerView.setAdapter(mListMessengerAdapter);
        getPresenter().getListMessage();
    }

    @Subscribe(threadMode = ThreadMode.MAIN)
    public void onUpdateMessages(OnUpdateMessagesEvent event) {
        getPresenter().getListMessage();
    }

    @Override
    protected String getTitle() {
        return getString(R.string.messages);
    }

    @Override
    protected Class<? extends FragmentPresenter> onRegisterPresenter() {
        return ListMessengerPresenter.class;
    }

    @Override
    public void updateListRoom(ArrayList<ChatRoom> chatRooms) {
        mListMessengerAdapter.setmChatRooms(chatRooms);
    }

    @Override
    public void onLoadDone() {
        super.onLoadDone();
        swipeRefreshLayout.setRefreshing(false);
    }

    @Override
    public void onLoading() {
        super.onLoading();
        swipeRefreshLayout.setRefreshing(true);
    }

    @Override
    public void goChatRoom(ChatRoom chatRoom) {
        replaceFragment(MessengerFragment.newInstance(chatRoom), true);
    }
}
