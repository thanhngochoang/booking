package com.paditech.mvpbase.screen.find_photographer;

import android.app.DatePickerDialog;
import androidx.recyclerview.widget.RecyclerView;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.ImageView;

import com.paditech.mvpbase.R;
import com.paditech.mvpbase.common.utils.ImageUtil;
import com.paditech.mvpbase.screen.home.ImageAdapter;

/**
 * Created by Fx570ex on 25-11-2017.
 */

public class ImagerQuickAdapter extends RecyclerView.Adapter<RecyclerView.ViewHolder> {
    private OnViewImageListener mOnViewImageListener;

    public void setmOnViewImageListener(OnViewImageListener mOnViewImageListener) {
        this.mOnViewImageListener = mOnViewImageListener;
    }

    @Override
    public RecyclerView.ViewHolder onCreateViewHolder(ViewGroup parent, int viewType) {
        View oView = LayoutInflater.from(parent.getContext()).inflate(R.layout.item_image, parent, false);
        return new ImageHolder(oView);
    }

    protected class ImageHolder extends RecyclerView.ViewHolder {
        private ImageView imageView;

        public ImageHolder(View itemView) {
            super(itemView);
            imageView = (ImageView) itemView;

        }

        private void bindData() {
            final String url = "https://orig00.deviantart.net/7e54/f/2008/002/4/5/red_tree_by_nayein.jpg";
            ImageUtil.loadImage(imageView.getContext(), url, imageView);
            itemView.setOnClickListener(new View.OnClickListener() {
                @Override
                public void onClick(View v) {
                    if (mOnViewImageListener != null) mOnViewImageListener.onView(url);
                }
            });
        }
    }

    @Override
    public void onBindViewHolder(RecyclerView.ViewHolder holder, int position) {
        ImageHolder imageHolder = (ImageHolder) holder;
        imageHolder.bindData();
    }

    @Override
    public int getItemCount() {
        return 0;
    }

    public interface OnViewImageListener {
        void onView(String url);
    }
}
