package com.paditech.mvpbase.common.utils.get_image;

import android.support.v7.widget.GridLayoutManager;
import android.support.v7.widget.RecyclerView;
import android.support.v7.widget.Toolbar;
import android.view.LayoutInflater;
import android.view.Menu;
import android.view.MenuItem;
import android.view.View;
import android.view.ViewGroup;
import android.widget.FrameLayout;
import android.widget.ImageView;
import android.widget.TextView;

import com.paditech.mvpbase.R;
import com.paditech.mvpbase.common.mvp.activity.ActivityPresenter;
import com.paditech.mvpbase.common.mvp.activity.MVPActivity;
import com.paditech.mvpbase.common.utils.CommonUtil;
import com.paditech.mvpbase.common.utils.ImageUtil;

import org.greenrobot.eventbus.EventBus;

import java.io.File;
import java.util.ArrayList;

import butterknife.BindView;
import butterknife.ButterKnife;

/**
 * Created by ThanhNgocHoang on 8/9/2017.
 */

public class SelectMultiActivity extends MVPActivity<SelectMultiContact.PresenterViewOps> implements SelectMultiContact.ViewOps {

    @BindView(R.id.tool_bar)
    Toolbar toolbar;
    @BindView(R.id.recycler_view)
    RecyclerView recyclerView;
    @BindView(R.id.tv_title)
    TextView tvTitle;

    private GridPhotoAdapter mGridPhotoAdapter;

    @Override
    public int getContentView() {
        return R.layout.act_select_multi;
    }

    @Override
    public void initView() {
        tvTitle.setText(getString(R.string.select_multi_photo));
        toolbar.setNavigationIcon(R.drawable.icon_back_white_topbar);
        setSupportActionBar(toolbar);
        setTitle("");
        getSupportActionBar().setDisplayHomeAsUpEnabled(true);
        getSupportActionBar().setDisplayShowHomeEnabled(true);
        setRecyclerView();
    }

    private void setRecyclerView() {
        mGridPhotoAdapter = new GridPhotoAdapter();
        recyclerView.setLayoutManager(new GridLayoutManager(this, 3));
        recyclerView.setAdapter(mGridPhotoAdapter);
//        getPresenter().getAllPhotos(this);
    }

    @Override
    public boolean onCreateOptionsMenu(Menu menu) {
        getMenuInflater().inflate(R.menu.menu_done_toolbar, menu);
        return super.onCreateOptionsMenu(menu);
    }

    @Override
    public boolean onOptionsItemSelected(MenuItem item) {
        int id = item.getItemId();
        switch (id) {
            case R.id.btn_done:
                EventBus.getDefault().postSticky(mGridPhotoAdapter.getListSelected());
                finish();
                break;
            case android.R.id.home:
                finish();
                break;
        }
        return super.onOptionsItemSelected(item);
    }

    @Override
    protected Class<? extends ActivityPresenter> onRegisterPresenter() {
        return SelectMultiPresenter.class;
    }

    @Override
    public void onUpdatePhotos(final ArrayList<String> listPhotos) {
        runOnUiThread(new Runnable() {
            @Override
            public void run() {
                mGridPhotoAdapter.setmListPhoto(listPhotos);
            }
        });
    }

    public class GridPhotoAdapter extends RecyclerView.Adapter<RecyclerView.ViewHolder> {
        private ArrayList<String> mListPhoto;
        private int size;
        private ArrayList<String> mListSelected;

        public GridPhotoAdapter() {
            mListPhoto = new ArrayList<>();
            mListSelected = new ArrayList<>();
            size = (CommonUtil.getWidthScreen(SelectMultiActivity.this) / 3);
        }

        public ArrayList<String> getListSelected() {
            return mListSelected;
        }

        void setmListPhoto(ArrayList<String> mListPhoto) {
            this.mListPhoto = mListPhoto;
            notifyDataSetChanged();
        }

        @Override
        public RecyclerView.ViewHolder onCreateViewHolder(ViewGroup viewGroup, int i) {
            View view = LayoutInflater.from(viewGroup.getContext()).inflate(R.layout.item_photo_select, viewGroup, false);
            return new ImageHolder(view);
        }

        @Override
        public void onBindViewHolder(RecyclerView.ViewHolder viewHolder, int i) {
            ImageHolder imageHolder = (ImageHolder) viewHolder;
            imageHolder.bindData(i);
        }

        @Override
        public int getItemCount() {
            return mListPhoto.size();
        }

        protected class ImageHolder extends RecyclerView.ViewHolder {
            @BindView(R.id.image)
            ImageView image;
            @BindView(R.id.select_layout)
            ImageView selectLayout;
            @BindView(R.id.item_layout)
            FrameLayout itemLayout;

            ImageHolder(View itemView) {
                super(itemView);
                ButterKnife.bind(this, itemView);
            }

            public void bindData(final int pos) {
                try {
                    itemLayout.getLayoutParams().width = size;
                    itemLayout.getLayoutParams().height = size;
                    ImageUtil.loadImage(itemView.getContext(), new File(mListPhoto.get(pos)), image, R.color.gray_light, R.color.gray_light);
                    if (mListSelected.contains(mListPhoto.get(pos))) {
                        selectLayout.setVisibility(View.VISIBLE);
                    } else selectLayout.setVisibility(View.GONE);

                    itemLayout.setOnClickListener(new View.OnClickListener() {
                        @Override
                        public void onClick(View view) {
                            if (mListSelected.contains(mListPhoto.get(pos))) {
                                mListSelected.remove(mListPhoto.get(pos));
                            } else mListSelected.add(mListPhoto.get(pos));
                            notifyDataSetChanged();
                        }
                    });
                } catch (Exception e) {
                    e.printStackTrace();
                }
            }
        }
    }
}
