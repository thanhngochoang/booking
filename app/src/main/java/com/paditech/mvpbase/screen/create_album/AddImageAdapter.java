package com.paditech.mvpbase.screen.create_album;

import android.app.Activity;
import androidx.recyclerview.widget.RecyclerView;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.ImageView;

import com.paditech.mvpbase.R;
import com.paditech.mvpbase.common.utils.CommonUtil;
import com.paditech.mvpbase.common.utils.ImageUtil;

import java.util.ArrayList;

/**
 * Created by ThanhNgocHoang on 12/4/2017.
 */

public class AddImageAdapter extends RecyclerView.Adapter<RecyclerView.ViewHolder> {
    public static final int TYPE_ADD = 1;
    public static final int TYPE_PHOTO = 0;

    private ArrayList<String> mListPhotos;
    private int size, padding;
    private OnAddImageListener mOnAddImageListener;

    public ArrayList<String> getmListPhotos() {
        return mListPhotos;
    }

    public void setmOnAddImageListener(OnAddImageListener mOnAddImageListener) {
        this.mOnAddImageListener = mOnAddImageListener;
    }

    public AddImageAdapter(Activity activity) {
        mListPhotos = new ArrayList<>();
        padding = activity.getResources().getDimensionPixelSize(R.dimen.margin_small);
        size = (int) ((CommonUtil.getWidthScreen(activity) - padding * 4) / 3);
    }

    public void addPhoto(String photo) {
        this.mListPhotos.add(photo);
        notifyDataSetChanged();
    }

    public void addPhotos(ArrayList<String> photo) {
        this.mListPhotos.addAll(photo);
        notifyDataSetChanged();
    }

    @Override
    public int getItemViewType(int position) {
        if (position == 0) return TYPE_ADD;
        return TYPE_PHOTO;
    }

    @Override
    public RecyclerView.ViewHolder onCreateViewHolder(ViewGroup parent, int viewType) {
        if (viewType == TYPE_ADD) {
            return new AddImageHolder(LayoutInflater.from(parent.getContext()).inflate(R.layout.item_add_image, parent, false));
        } else
            return new PhotoHolder(LayoutInflater.from(parent.getContext()).inflate(R.layout.item_add_image, parent, false));
    }

    @Override
    public void onBindViewHolder(RecyclerView.ViewHolder holder, int position) {
        if (getItemViewType(position) == TYPE_ADD) {
            AddImageHolder addImageHolder = (AddImageHolder) holder;
            addImageHolder.itemView.setOnClickListener(new View.OnClickListener() {
                @Override
                public void onClick(View v) {
                    if (mOnAddImageListener != null) {
                        mOnAddImageListener.onAddImageClick();
                    }
                }
            });
        } else {
            PhotoHolder photoHolder = (PhotoHolder) holder;
            photoHolder.bindData(position);
        }
    }

    @Override
    public int getItemCount() {
        if (mListPhotos != null) return mListPhotos.size() + 1;
        return 1;
    }

    protected class AddImageHolder extends RecyclerView.ViewHolder {

        public AddImageHolder(View itemView) {
            super(itemView);
            RecyclerView.LayoutParams params = (RecyclerView.LayoutParams) itemView.getLayoutParams();
            params.width = size;
            params.height = size;
          /*  params.leftMargin = padding;
            params.topMargin = padding;*/
        }

    }

    protected class PhotoHolder extends RecyclerView.ViewHolder {
        ImageView imageView;
        private RecyclerView.LayoutParams params;

        public PhotoHolder(View itemView) {
            super(itemView);
            imageView = itemView.findViewById(R.id.image);
            imageView.setImageResource(R.color.white);
            imageView.setScaleType(ImageView.ScaleType.CENTER_CROP);
            params = (RecyclerView.LayoutParams) itemView.getLayoutParams();
            params.height = size;
            params.width = size;
        }

        private void bindData(int pos) {
            try {
                /*params.topMargin = padding;
                params.bottomMargin = 0;
                switch (pos % 3) {
                    case 0:
                        params.leftMargin = padding;
                        params.rightMargin = 0;
                        break;
                    case 1:
                        params.leftMargin = padding;
                        params.rightMargin = padding;
                        break;
                    case 2:
                        params.leftMargin = 0;
                        params.rightMargin = padding;
                        break;
                }*/
                ImageUtil.loadImage(itemView.getContext(), mListPhotos.get(pos - 1), imageView);
            } catch (Exception e) {
                e.printStackTrace();
            }
        }
    }

    public interface OnAddImageListener {
        void onAddImageClick();
    }
}
