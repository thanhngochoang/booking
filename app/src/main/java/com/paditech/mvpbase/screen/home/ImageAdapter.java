package com.paditech.mvpbase.screen.home;

import androidx.recyclerview.widget.RecyclerView;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.ImageView;

import com.paditech.mvpbase.R;
import com.paditech.mvpbase.common.utils.ImageUtil;

import java.util.Random;


/**
 * Created by ThanhNgocHoang on 11/4/2017.
 */

public class ImageAdapter extends RecyclerView.Adapter<RecyclerView.ViewHolder> {
    private OnViewImageListener mOnViewImageListener;

    public void setmOnViewImageListener(OnViewImageListener mOnViewImageListener) {
        this.mOnViewImageListener = mOnViewImageListener;
    }

    @Override
    public RecyclerView.ViewHolder onCreateViewHolder(ViewGroup parent, int viewType) {
        View view = LayoutInflater.from(parent.getContext()).inflate(R.layout.item_image, parent, false);
        return new ImageHolder(view);
    }

    @Override
    public void onBindViewHolder(RecyclerView.ViewHolder holder, int position) {
        ImageHolder imageHolder = (ImageHolder) holder;
        imageHolder.bindData();
    }

    @Override
    public int getItemCount() {
        return 3;
    }

    protected class ImageHolder extends RecyclerView.ViewHolder {

        private ImageView imageView;

        public ImageHolder(View itemView) {
            super(itemView);
            imageView = (ImageView) itemView;
        };
        final String getFlick(){
            String  Url = "http://api.flickr.com/services/rest/?";
            return  Url;
        }
        final String getUrl (){
            final String arrUrl[] = {"https://www.w3schools.com/w3images/fjords.jpg" ,
                    "https://orig00.deviantart.net/7e54/f/2008/002/4/5/red_tree_by_nayein.jpg" ,
                    "http://www.qygjxz.com/data/out/114/5841762-image.jpg"};
            return arrUrl[ new Random().nextInt(arrUrl.length)] ;
        }
        private void bindData() {

            final String url = getUrl();
            ImageUtil.loadImage(imageView.getContext(), url, imageView);
            itemView.setOnClickListener(new View.OnClickListener() {
                @Override
                public void onClick(View view) {
                    if (mOnViewImageListener != null) mOnViewImageListener.onView(url);
                }
            });
        }
    }

    public interface OnViewImageListener {
        void onView(String url);
    }
}
