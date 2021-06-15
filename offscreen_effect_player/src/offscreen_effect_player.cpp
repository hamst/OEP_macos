#include "offscreen_effect_player.hpp"
#include "offscreen_render_target.h"

#include <iostream>

namespace bnb
{
    ioep_sptr interfaces::offscreen_effect_player::create(
        int32_t width, int32_t height, bool manual_audio, std::optional<iort_sptr> ort = std::nullopt)
    {
        if (!ort.has_value()) {
            ort = std::make_shared<bnb::offscreen_render_target>(width, height);
        }

        // we use "new" instead of "make_shared" because the constructor in "offscreen_effect_player" is private
        return oep_sptr(new bnb::offscreen_effect_player(width, height, manual_audio, *ort));
    }

    offscreen_effect_player::offscreen_effect_player(int32_t width, int32_t height, bool manual_audio,
        iort_sptr offscreen_render_target)
            : m_ep(bnb::interfaces::effect_player::create( {
                width, height,
                bnb::interfaces::nn_mode::automatically,
                bnb::interfaces::face_search_mode::good,
                false, manual_audio }))
            , m_ort(offscreen_render_target)
            , m_scheduler(1)
    {
        auto task = [this, width, height]() {
            render_thread_id = std::this_thread::get_id();
            m_ort->init();
            m_ep->surface_created(width, height);
        };

        m_scheduler.enqueue(task);
    }

    offscreen_effect_player::~offscreen_effect_player()
    {
        m_ep->surface_destroyed();
    }

    void offscreen_effect_player::process_image_async(std::shared_ptr<full_image_t> image, oep_pb_ready_cb callback,
                                                      std::optional<interfaces::orient_format> target_orient)
    {
        if (!target_orient.has_value()) {
            target_orient = { image->get_format().orientation, true };
        }

        auto task = [this, image, callback, target_orient]() {
            if (m_current_frame == nullptr) {
                m_current_frame = std::make_shared<pixel_buffer>(shared_from_this(),
                    image->get_format().width, image->get_format().height, image->get_format().orientation);
            }

            if (m_current_frame->is_locked()) {
                std::cout << "[Warning] The interface for processing the previous frame is lock" << std::endl;
                callback(std::nullopt);
                return;
            }

            if (m_incoming_frame_queue_task_count == 1) {
                m_current_frame->lock();
                m_ort->prepare_rendering();
                m_ep->push_frame(std::move(*image));
                while (m_ep->draw() < 0) {
                    std::this_thread::yield();
                }
                m_ort->orient_image(*target_orient);
                callback(m_current_frame);
                m_current_frame->unlock();
            } else {
                callback(std::nullopt);
            }
            --m_incoming_frame_queue_task_count;
        };

        ++m_incoming_frame_queue_task_count;
        m_scheduler.enqueue(task);
    }

    void offscreen_effect_player::surface_changed(int32_t width, int32_t height)
    {
        auto task = [this, width, height]() {
            m_ep->surface_changed(width, height);
            m_ep->effect_manager()->set_effect_size(width, height);

            m_current_frame.reset();
            m_ort->surface_changed(width, height);
        };

        m_scheduler.enqueue(task);
    }

    void offscreen_effect_player::load_effect(const std::string& effect_path, oep_load_effect_cb cb)
    {
        auto task = [this, effect_path, cb]() {
            if (auto e_manager = m_ep->effect_manager()) {
                e_manager->load(effect_path);
                if (cb) cb(true);
            } else {
                std::cout << "[Error] effect manager not initialized" << std::endl;
                if (cb) cb(false);
            }
        };

        m_scheduler.enqueue(task);
    }

    void offscreen_effect_player::unload_effect()
    {
        load_effect("", nullptr);
    }

    bool offscreen_effect_player::call_js_method(const std::string& method, const std::string& param)
    {
        if (auto e_manager = m_ep->effect_manager()) {
            if (auto effect = e_manager->current()) {
                effect->call_js_method(method, param);
                return true;
            } else {
                std::cout << "[Error] effect not loaded" << std::endl;
                return false;
            }
        } else {
            std::cout << "[Error] effect manager not initialized" << std::endl;
            return false;
        }
    }

    void offscreen_effect_player::read_current_buffer(std::function<void(bnb::data_t data)> callback)
    {
        if (std::this_thread::get_id() == render_thread_id) {
            callback(m_ort->read_current_buffer());
            return;
        }

        oep_wptr this_ = shared_from_this();
        auto task = [this_, callback]() {
            if (auto this_sp = this_.lock()) {
                callback(this_sp->m_ort->read_current_buffer());
            }
        };
        m_scheduler.enqueue(task);
    }

    void offscreen_effect_player::read_pixel_buffer(oep_image_ready_pb_cb callback, interfaces::image_format format)
    {
        if (std::this_thread::get_id() == render_thread_id) {
            callback(m_ort->get_image(format));
            return;
        }

        oep_wptr this_ = shared_from_this();
        auto task = [this_, callback, format]() {
            if (auto this_sp = this_.lock()) {
                callback(this_sp->m_ort->get_image(format));
            }
        };
        m_scheduler.enqueue(task);
    }

// static
bool interfaces::offscreen_effect_player::initialize_if_needed(const std::vector<std::string> &path_to_resources, const std::string &client_token) {

    static std::once_flag onceToken;
    static std::unique_ptr<bnb::utility> instance;

    std::call_once(onceToken, [path_to_resources, client_token]() {
        instance = std::make_unique<bnb::utility>(path_to_resources, client_token);
    });

    return instance.get();
}

} // bnb
