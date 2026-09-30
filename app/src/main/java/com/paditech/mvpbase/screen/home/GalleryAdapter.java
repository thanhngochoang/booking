package com.paditech.mvpbase.screen.home;

import android.support.v7.widget.LinearLayoutManager;
import android.support.v7.widget.RecyclerView;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.ImageView;
import android.widget.TextView;

import com.paditech.mvpbase.R;
import com.paditech.mvpbase.common.model.Album;
import com.paditech.mvpbase.common.utils.ImageUtil;
import com.paditech.mvpbase.common.view.AutoTopImageLayout;

import java.util.ArrayList;

import butterknife.BindView;
import butterknife.ButterKnife;

/**
 * Created by ThanhNgocHoang on 11/4/2017.
 */

public class GalleryAdapter extends RecyclerView.Adapter<RecyclerView.ViewHolder> {

    private ArrayList<Album> mListAlbums;
    private ImageAdapter.OnViewImageListener mOnViewImageListener;

    public GalleryAdapter() {
        mListAlbums = new ArrayList<>();
    }

    private ItemGalleryClickListener mItemGalleryClickListener;

    public void setmItemGalleryClickListener(ItemGalleryClickListener mItemGalleryClickListener) {
        this.mItemGalleryClickListener = mItemGalleryClickListener;
    }

    public void setmListAlbums(ArrayList<Album> mListAlbums) {
        this.mListAlbums = mListAlbums;
        notifyDataSetChanged();
    }

    public void setmOnViewImageListener(ImageAdapter.OnViewImageListener mOnViewImageListener) {
        this.mOnViewImageListener = mOnViewImageListener;
    }

    @Override
    public RecyclerView.ViewHolder onCreateViewHolder(ViewGroup parent, int viewType) {
        View view = LayoutInflater.from(parent.getContext()).inflate(R.layout.item_gallery, parent, false);
        return new GalleryHolder(view);
    }

    @Override
    public void onBindViewHolder(RecyclerView.ViewHolder holder, int position) {
        GalleryHolder galleryHolder = (GalleryHolder) holder;
        galleryHolder.bindData(position);
    }

    @Override
    public int getItemCount() {
        if (mListAlbums != null) return mListAlbums.size();
        return 0;
    }

    protected class GalleryHolder extends RecyclerView.ViewHolder {
        @BindView(R.id.tv_name)
        TextView tvName;
        @BindView(R.id.tv_count)
        TextView tvCount;
        @BindView(R.id.avatar)
        ImageView avatar;
        @BindView(R.id.auto_image_layout)
        AutoTopImageLayout autoTopImageLayout;
        @BindView(R.id.tv_desc)
        TextView tvDesc;
        @BindView(R.id.tv_address)
        TextView tvAddress;

        public GalleryHolder(View itemView) {
            super(itemView);
            ButterKnife.bind(this, itemView);
        }

        private void bindData(int pos) {
            try {
                final Album album = mListAlbums.get(pos);
                tvName.setText(album.getAlbum_name());
                tvDesc.setText(album.getAlbum_desc());
                tvAddress.setText(album.getAlbum_address());
                ImageUtil.loadImage(itemView.getContext(), album.getPhotographer_image(), avatar, R.color.white, R.color.white);
                if (album.getAlbum_files() != null) {
                    autoTopImageLayout.setVisibility(View.VISIBLE);
                    tvCount.setText(String.format(itemView.getContext().getString(R.string.image_counts_format), album.getAlbum_files().size()));
                    autoTopImageLayout.setmListImages(album.getAlbum_files());
                } else {
                    tvCount.setText(String.format(itemView.getContext().getString(R.string.image_counts_format), 0));
                    autoTopImageLayout.setVisibility(View.GONE);
                }

                avatar.setOnClickListener(new View.OnClickListener() {
                    @Override
                    public void onClick(View v) {
                        if (mItemGalleryClickListener != null)
                            mItemGalleryClickListener.onProfileView(album.getPhotographer_id());
                    }
                });
            } catch (Exception e) {
                e.printStackTrace();
            }

        }
    }

    public interface ItemGalleryClickListener {
        void onProfileView(String userId);
    }
}
