package com.paditech.mvpbase.screen.find_photographer;

import android.support.v7.widget.AppCompatRatingBar;
import android.support.v7.widget.RecyclerView;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.TextView;

import com.paditech.mvpbase.R;
import com.paditech.mvpbase.common.model.User;
import com.paditech.mvpbase.common.utils.ImageUtil;
import com.paditech.mvpbase.common.view.AutoTopImageLayout;

import java.util.ArrayList;

import butterknife.BindView;
import butterknife.ButterKnife;
import de.hdodenhof.circleimageview.CircleImageView;

/**
 * Created by ThanhNgocHoang on 11/15/2017.
 */

public class PhotographerAdapter extends RecyclerView.Adapter<RecyclerView.ViewHolder> {
    private ArrayList<User> mListPhotographers;
    private ImagerQuickAdapter.OnViewImageListener mOnViewImageListener;
    private OnBookClickListener mOnBookClickListener;

    public PhotographerAdapter() {
        mListPhotographers = new ArrayList<>();
    }

    public void setmOnBookClickListener(OnBookClickListener mOnBookClickListener) {
        this.mOnBookClickListener = mOnBookClickListener;
    }

    public void setmListPhotographers(ArrayList<User> mListPhotographers) {
        this.mListPhotographers = mListPhotographers;
        notifyDataSetChanged();
    }

    public void setmOnViewImageListener(ImagerQuickAdapter.OnViewImageListener mImagerQuickAdapter) {
        this.mOnViewImageListener = mImagerQuickAdapter;
    }

    @Override
    public RecyclerView.ViewHolder onCreateViewHolder(ViewGroup parent, int viewType) {
        return new GrapherHolder(LayoutInflater.from(parent.getContext()).inflate(R.layout.item_photographer, parent, false));
    }

    @Override
    public void onBindViewHolder(RecyclerView.ViewHolder holder, int position) {
        GrapherHolder grapherHolder = (GrapherHolder) holder;
        grapherHolder.bindData(position);
    }

    @Override
    public int getItemCount() {
        if (mListPhotographers != null)
            return mListPhotographers.size();
        return 0;
    }

    protected class GrapherHolder extends RecyclerView.ViewHolder {
        @BindView(R.id.avatar)
        CircleImageView avatar;
        @BindView(R.id.tv_name)
        TextView tvName;
        @BindView(R.id.tv_star)
        AppCompatRatingBar tvStar;
        @BindView(R.id.tv_address)
        TextView tvAddress;
        @BindView(R.id.tv_count)
        TextView tvCount;
        @BindView(R.id.auto_image_layout)
        AutoTopImageLayout autoTopImageLayout;
        @BindView(R.id.btn_book)
        View btnBook;

        public GrapherHolder(View itemView) {
            super(itemView);
            ButterKnife.bind(this, itemView);

        }

        private void bindData(int pos) {
            try {
                final User photographer = mListPhotographers.get(pos);
                tvName.setText(photographer.getFull_name());
                tvStar.setRating((float) photographer.getRate());
                tvAddress.setText(photographer.getAddress());
                ImageUtil.loadImage(itemView.getContext(), photographer.getAvatar(), avatar);
                ArrayList<String> list = new ArrayList<>();
                list.add("http://media.dulich24.com.vn/diemden/cao-nguyen-moc-chau-son-la-3356/91cc2206-a0ef-4fb1-86e3-a14857095069-14.jpg");
                list.add("https://lh6.googleusercontent.com/jwbecUaBRNk43kkH8_2sEgQLHUOa5C_GHejBY2q9EsE=w691-h461-no");
                list.add("http://www.xomnhiepanh.com/uploads/gallery/2008/01/1200279245.jpg");
                autoTopImageLayout.setmListImages(list);
                btnBook.setOnClickListener(new View.OnClickListener() {
                    @Override
                    public void onClick(View v) {
                        if (mOnBookClickListener != null) mOnBookClickListener.onBook(photographer);
                    }
                });
            } catch (Exception e) {
                e.printStackTrace();
            }

        }
    }

    public interface OnBookClickListener {
        void onBook(User photographer);
    }
}
